import {
  FieldValue,
  Firestore,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  isStuckPendingJob,
  selectUidsForSyncNudge,
  shouldMarkStuck,
  STUCK_PENDING_MS,
  uidFromParseJobPath,
} from "./parseJobMaintenance";

const STUCK_QUERY_LIMIT = 100;

/**
 * Phase 3 maintenance: mark long-pending parse jobs and nudge the app to drain.
 *
 * Does not parse SMS server-side (Phase 1). Opening the app after a nudge runs
 * the existing IngestQueueDrain + IngestParsePipeline path.
 */
export const retryStuckParseJobs = onSchedule(
  {
    region: "asia-south1",
    schedule: "every 6 hours",
    timeZone: "Asia/Kolkata",
    maxInstances: 1,
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();
    const cutoff = Timestamp.fromMillis(nowMs - STUCK_PENDING_MS);

    const snapshot = await db
      .collectionGroup("parse_jobs")
      .where("status", "==", "pending")
      .where("updatedAt", "<", cutoff)
      .limit(STUCK_QUERY_LIMIT)
      .get();

    if (snapshot.empty) {
      logger.info("retryStuckParseJobs: no stuck pending jobs");
      return;
    }

    let marked = 0;
    const nudgeUids: string[] = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const updatedAt = (data.updatedAt as Timestamp | undefined)?.toDate() ?? null;
      const stuckAt = (data.stuckAt as Timestamp | undefined)?.toDate() ?? null;

      const job = {
        status: (data.status as string) ?? "pending",
        updatedAt,
        stuckAt,
      };

      if (!isStuckPendingJob(job, nowMs)) continue;

      if (shouldMarkStuck(job)) {
        await doc.ref.update({
          stuckAt: FieldValue.serverTimestamp(),
        });
        marked++;
      }

      const uid = uidFromParseJobPath(doc.ref.path);
      if (uid) nudgeUids.push(uid);
    }

    const uidsToNudge = selectUidsForSyncNudge(nudgeUids);
    let nudgesSent = 0;

    for (const uid of uidsToNudge) {
      const sent = await sendIngestSyncNudge(db, uid);
      if (sent) nudgesSent++;
    }

    logger.info("retryStuckParseJobs complete", {
      scanned: snapshot.size,
      marked,
      nudgesSent,
    });
  },
);

async function sendIngestSyncNudge(
  db: Firestore,
  uid: string,
): Promise<boolean> {
  const tokensSnap = await db
    .collection("users")
    .doc(uid)
    .collection("fcm_tokens")
    .get();

  const tokens = tokensSnap.docs
    .map((d) => (d.data().token as string | undefined) ?? d.id)
    .filter((t): t is string => !!t);

  if (tokens.length === 0) {
    logger.info("retryStuckParseJobs: no FCM tokens for sync nudge", {uid});
    return false;
  }

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "SMS waiting to sync",
        body: "Open Money Matters to update your ledger.",
      },
      data: {type: "ingest_sync"},
      apns: {payload: {aps: {sound: "default"}}},
    });

    const stale: string[] = [];
    response.responses.forEach((r, i) => {
      const code = r.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[i]);
      }
    });

    await Promise.all(
      stale.map((t) =>
        db
          .collection("users")
          .doc(uid)
          .collection("fcm_tokens")
          .doc(t)
          .delete()
          .catch(() => undefined),
      ),
    );

    return response.successCount > 0;
  } catch (err) {
    logger.error("retryStuckParseJobs: FCM nudge failed", {uid, err});
    return false;
  }
}
