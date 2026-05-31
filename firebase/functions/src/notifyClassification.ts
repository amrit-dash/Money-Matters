import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";

// Sends a "needs classification" push when a new transaction lands that the
// rules parser could not categorize. Real delivery requires a paid Apple
// Developer account (APNs); on a free personal team the device simply has no
// valid token and this no-ops. The in-app "Needs your input" inbox is the
// always-working fallback regardless of push availability.
export const notifyClassification = onDocumentCreated(
  {
    region: "asia-south1",
    document: "users/{uid}/transactions/{txId}",
    maxInstances: 5,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const tx = snap.data();

    const needs =
      tx.needsClassification === true ||
      tx.ambiguous === true ||
      tx.unmatched === true;
    if (!needs) return;

    const {uid, txId} = event.params;
    const db = getFirestore();
    const tokensSnap = await db
      .collection("users")
      .doc(uid)
      .collection("fcm_tokens")
      .get();

    const tokens = tokensSnap.docs
      .map((d) => (d.data().token as string | undefined) ?? d.id)
      .filter((t): t is string => !!t);
    if (tokens.length === 0) {
      logger.info("No FCM tokens — relying on in-app inbox", {uid, txId});
      return;
    }

    const merchant = (tx.merchant as string | undefined) ?? "A transaction";
    const amount = tx.amount as number | undefined;
    const body = amount != null ?
      `${merchant} · ₹${amount} needs a category` :
      `${merchant} needs a category`;

    try {
      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {title: "Categorize a transaction", body},
        data: {txId, type: "classify"},
        apns: {payload: {aps: {sound: "default"}}},
      });

      // Prune tokens APNs/FCM rejected as unregistered.
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
    } catch (err) {
      logger.error("notifyClassification send failed", {uid, txId, err});
    }
  },
);
