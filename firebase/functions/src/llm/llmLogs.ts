import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

const MAX_LOGS = 100;

export type LlmLogLevel = "error" | "warn" | "info";

export interface LlmLogInput {
  level: LlmLogLevel;
  message: string;
  detail?: string | null;
  provider?: string | null;
  model?: string | null;
  source: string;
}

export async function writeLlmLog(uid: string, input: LlmLogInput): Promise<void> {
  try {
    const db = getFirestore();
    const col = db.collection("users").doc(uid).collection("llm_logs");
    await col.add({
      level: input.level,
      message: input.message,
      detail: input.detail ?? null,
      provider: input.provider ?? null,
      model: input.model ?? null,
      source: input.source,
      createdAt: Timestamp.now(),
    });

    const excess = await col
      .orderBy("createdAt", "desc")
      .offset(MAX_LOGS)
      .limit(50)
      .get();
    if (!excess.empty) {
      const batch = db.batch();
      for (const doc of excess.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("writeLlmLog failed", err);
  }
}
