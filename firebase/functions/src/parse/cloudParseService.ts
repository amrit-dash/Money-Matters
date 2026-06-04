import {
  FieldValue,
  Firestore,
  Timestamp,
  DocumentReference,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {matchCategory, matchPaymentSourceFromIngest} from "./paymentSourceMatch";
import {parseRawIngestRules} from "./rulesParser";
import {
  CategoryRecord,
  PaymentSourceRecord,
  RawIngestInput,
} from "./types";

export const PIPELINE_RULES_VERSION = "rules-v1";

export interface CloudParseOutcome {
  status: "done" | "skipped" | "failed";
  transactionCreated: boolean;
  error?: string;
}

function userRef(db: Firestore, uid: string) {
  return db.collection("users").doc(uid);
}

async function loadPaymentSources(
  db: Firestore,
  uid: string,
): Promise<PaymentSourceRecord[]> {
  const snap = await userRef(db, uid).collection("payment_sources")
    .orderBy("createdAt")
    .get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: (data.name as string) ?? "",
      last4: data.last4 as string | undefined,
      senderHints: (data.senderHints as string[] | undefined) ?? [],
      merchantHints: (data.merchantHints as string[] | undefined) ?? [],
      bodyPatterns: (data.bodyPatterns as string[] | undefined) ?? [],
    };
  });
}

async function loadCategories(
  db: Firestore,
  uid: string,
): Promise<CategoryRecord[]> {
  const snap = await userRef(db, uid).collection("categories").get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: (data.id as string | undefined) ?? doc.id,
      merchantRules: (data.merchantRules as string[] | undefined) ?? [],
    };
  });
}

function toDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return new Date(parsed);
  }
  return new Date();
}

/**
 * Parses one raw ingest in Firestore and marks the parse job complete.
 * Idempotent: safe to retry on the same job.
 */
export async function runCloudParse(
  db: Firestore,
  uid: string,
  rawIngestId: string,
  parseJobRef: DocumentReference,
): Promise<CloudParseOutcome> {
  const jobSnap = await parseJobRef.get();
  if (!jobSnap.exists) {
    return {status: "skipped", transactionCreated: false};
  }

  const jobData = jobSnap.data() ?? {};
  if (jobData.status === "done") {
    return {status: "skipped", transactionCreated: false};
  }
  if (jobData.status === "failed") {
    return {status: "skipped", transactionCreated: false};
  }

  const rawRef = userRef(db, uid).collection("raw_ingests").doc(rawIngestId);
  const rawSnap = await rawRef.get();
  if (!rawSnap.exists) {
    await markParseJobFailed(parseJobRef, "raw_ingest not found");
    return {
      status: "failed",
      transactionCreated: false,
      error: "raw_ingest not found",
    };
  }

  const rawData = rawSnap.data() ?? {};
  const ingest: RawIngestInput = {
    id: rawIngestId,
    body: (rawData.body as string) ?? "",
    sender: (rawData.sender as string) ?? "",
    receivedAt: toDate(rawData.receivedAt),
  };

  try {
    const [sources, categories] = await Promise.all([
      loadPaymentSources(db, uid),
      loadCategories(db, uid),
    ]);

    const result = parseRawIngestRules(ingest);
    const now = FieldValue.serverTimestamp();
    let transactionCreated = false;

    if (result.classification === "transaction" && result.candidate) {
      const candidate = result.candidate;
      const paymentSourceId = matchPaymentSourceFromIngest({
        sender: ingest.sender,
        body: ingest.body,
        instrumentLast4: candidate.instrumentLast4,
        merchant: candidate.merchant,
        sources,
      });
      const categoryId = matchCategory(candidate.merchant, categories) ?? undefined;
      const needsClassification =
        candidate.type === "debit" && categoryId == null;

      const txRef = userRef(db, uid).collection("transactions").doc(rawIngestId);
      const existingTx = await txRef.get();
      if (!existingTx.exists) {
        await txRef.set({
          rawIngestId,
          amount: candidate.amount,
          currency: candidate.currency,
          merchant: candidate.merchant ?? null,
          timestamp: Timestamp.fromDate(candidate.timestamp),
          categoryId: categoryId ?? null,
          subcategoryId: null,
          paymentSourceId: paymentSourceId ?? null,
          unmatched: paymentSourceId == null,
          ambiguous: candidate.ambiguous || categoryId == null,
          excluded: false,
          type: candidate.type,
          needsClassification,
          classifiedBy: categoryId != null ? "rules" : null,
        });
        transactionCreated = true;
      }
    }

    await db.runTransaction(async (tx) => {
      const freshJob = await tx.get(parseJobRef);
      if (!freshJob.exists) return;
      const status = freshJob.data()?.status as string | undefined;
      if (status === "done") return;

      tx.update(parseJobRef, {
        status: "done",
        rulesVersion: PIPELINE_RULES_VERSION,
        error: null,
        updatedAt: now,
      });
      tx.update(rawRef, {
        processedAt: now,
      });
    });

    logger.info("Cloud parse complete", {
      uid,
      rawIngestId,
      classification: result.classification,
      transactionCreated,
    });

    return {
      status: result.classification === "transaction" ? "done" : "skipped",
      transactionCreated,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Cloud parse failed";
    logger.error("Cloud parse failed", {uid, rawIngestId, err});
    await markParseJobFailed(parseJobRef, message);
    return {
      status: "failed",
      transactionCreated: false,
      error: message,
    };
  }
}

async function markParseJobFailed(
  parseJobRef: DocumentReference,
  error: string,
): Promise<void> {
  await parseJobRef.update({
    status: "failed",
    error,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
