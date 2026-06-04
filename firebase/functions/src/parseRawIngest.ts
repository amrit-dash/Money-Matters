import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {runCloudParse} from "./parse/cloudParseService";

/**
 * Phase 1 cloud parse: when ingestSms creates a pending parse job, parse the
 * SMS server-side and write transactions + processedAt without opening the app.
 */
export const parseRawIngest = onDocumentCreated(
  {
    region: "asia-south1",
    document: "users/{uid}/parse_jobs/{jobId}",
    maxInstances: 10,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (data.status !== "pending") {
      logger.info("parseRawIngest: skip non-pending job", {
        jobId: event.params.jobId,
        status: data.status,
      });
      return;
    }

    const rawIngestId = data.rawIngestId as string | undefined;
    if (!rawIngestId || rawIngestId.trim().length === 0) {
      logger.warn("parseRawIngest: missing rawIngestId", {
        uid: event.params.uid,
        jobId: event.params.jobId,
      });
      return;
    }

    const db = getFirestore();
    await runCloudParse(
      db,
      event.params.uid,
      rawIngestId.trim(),
      snap.ref,
    );
  },
);
