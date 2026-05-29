import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import {AuthError, resolveUidFromBearer} from "./auth";
import {computeIdempotencyKey} from "./normalize";

const ALLOWED_SOURCES = new Set([
  "shortcuts-automation-v1",
  "manual-paste",
]);

export interface IngestPayload {
  body: string;
  sender: string;
  receivedAt: string;
  deviceId: string;
  source: string;
  batchHint: string | null;
}

interface ValidationResult {
  ok: true;
  payload: IngestPayload;
}

interface ValidationError {
  ok: false;
  message: string;
}

function validatePayload(body: unknown): ValidationResult | ValidationError {
  if (!body || typeof body !== "object") {
    return {ok: false, message: "Request body must be a JSON object"};
  }

  const data = body as Record<string, unknown>;

  if (typeof data.body !== "string" || !data.body.trim()) {
    return {ok: false, message: "body is required and must be a non-empty string"};
  }

  if (typeof data.sender !== "string" || !data.sender.trim()) {
    return {ok: false, message: "sender is required and must be a non-empty string"};
  }

  if (typeof data.receivedAt !== "string" || !data.receivedAt.trim()) {
    return {ok: false, message: "receivedAt is required and must be ISO8601 string"};
  }

  if (typeof data.deviceId !== "string" || !data.deviceId.trim()) {
    return {ok: false, message: "deviceId is required and must be a non-empty string"};
  }

  if (typeof data.source !== "string" || !ALLOWED_SOURCES.has(data.source)) {
    return {
      ok: false,
      message: `source must be one of: ${[...ALLOWED_SOURCES].join(", ")}`,
    };
  }

  if (data.batchHint !== null && data.batchHint !== undefined) {
    if (typeof data.batchHint !== "string") {
      return {ok: false, message: "batchHint must be null or a string"};
    }
  }

  return {
    ok: true,
    payload: {
      body: data.body,
      sender: data.sender,
      receivedAt: data.receivedAt,
      deviceId: data.deviceId.trim(),
      source: data.source,
      batchHint: (data.batchHint as string | null | undefined) ?? null,
    },
  };
}

function jsonResponse(
  res: Parameters<Parameters<typeof onRequest>[0]>[1],
  status: number,
  body: Record<string, unknown>,
): void {
  res.status(status).json(body);
}

// App Check is intentionally NOT enforced here: iOS Shortcuts POST JSON via
// "Get Contents of URL" and cannot attach Firebase App Check tokens. Protection
// is device Bearer token + idempotency + Firestore rules. The Flutter app uses
// App Check for Auth/Firestore SDK traffic (see lib/core/app_check/).
export const ingestSms = onRequest(
  {
    region: "asia-south1",
    cors: false,
    maxInstances: 10,
    // enforceAppCheck: false — required for Shortcuts automation ingest path
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.set("Allow", "POST");
      jsonResponse(res, 405, {ok: false, error: "Method not allowed"});
      return;
    }

    const validation = validatePayload(req.body);
    if (!validation.ok) {
      jsonResponse(res, 400, {ok: false, error: validation.message});
      return;
    }

    const {payload} = validation;

    let uid: string;
    try {
      const auth = await resolveUidFromBearer(
        req.get("Authorization"),
        payload.deviceId,
      );
      uid = auth.uid;
    } catch (err) {
      if (err instanceof AuthError) {
        jsonResponse(res, 401, {ok: false, error: err.message});
        return;
      }
      logger.error("Auth resolution failed", err);
      jsonResponse(res, 500, {ok: false, error: "Internal server error"});
      return;
    }

    let idempotencyKey: string;
    try {
      idempotencyKey = computeIdempotencyKey(
        payload.sender,
        payload.body,
        payload.receivedAt,
      );
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Invalid receivedAt";
      jsonResponse(res, 400, {ok: false, error: message});
      return;
    }

    const db = getFirestore();
    const rawIngestRef = db
      .collection("users")
      .doc(uid)
      .collection("raw_ingests")
      .doc(idempotencyKey);

    try {
      const existing = await rawIngestRef.get();
      if (existing.exists) {
        jsonResponse(res, 200, {
          ok: true,
          duplicate: true,
          id: idempotencyKey,
        });
        return;
      }

      const receivedAtTimestamp = Timestamp.fromDate(
        new Date(payload.receivedAt),
      );
      const now = FieldValue.serverTimestamp();

      let created = false;
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(rawIngestRef);
        if (snap.exists) {
          return;
        }

        created = true;

        tx.set(rawIngestRef, {
          body: payload.body,
          sender: payload.sender,
          receivedAt: receivedAtTimestamp,
          deviceId: payload.deviceId,
          source: payload.source,
          batchHint: payload.batchHint,
          createdAt: now,
          duplicate: false,
        });

        const parseJobRef = db
          .collection("users")
          .doc(uid)
          .collection("parse_jobs")
          .doc();

        tx.set(parseJobRef, {
          rawIngestId: idempotencyKey,
          status: "pending",
          rulesVersion: "1",
          error: null,
          updatedAt: now,
        });
      });

      if (!created) {
        jsonResponse(res, 200, {
          ok: true,
          duplicate: true,
          id: idempotencyKey,
        });
        return;
      }

      logger.info("Ingest created", {
        uid,
        idempotencyKey,
        source: payload.source,
        deviceId: payload.deviceId,
      });

      jsonResponse(res, 201, {
        ok: true,
        duplicate: false,
        id: idempotencyKey,
      });
    } catch (err) {
      logger.error("Ingest write failed", {uid, idempotencyKey, err});
      jsonResponse(res, 500, {ok: false, error: "Internal server error"});
    }
  },
);
