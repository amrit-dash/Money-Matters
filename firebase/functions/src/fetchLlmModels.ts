import {onCall, HttpsError} from "firebase-functions/v2/https";

import {credentialsFromRequest, fetchProviderModels} from "./llm/providers";
import {writeLlmLog} from "./llm/llmLogs";
import {loadUserLlmConfig} from "./llm/userLlmConfig";

export const fetchLlmModels = onCall(
  {region: "asia-south1", maxInstances: 10},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }

    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;
    const stored = await loadUserLlmConfig(uid);

    try {
      const creds = credentialsFromRequest(data, stored);
      const models = await fetchProviderModels(creds);
      await writeLlmLog(uid, {
        level: "info",
        message: `Fetched ${models.length} model(s)`,
        provider: creds.provider,
        model: creds.model,
        source: "fetchLlmModels",
      });
      return {ok: true, models};
    } catch (err) {
      const message = err instanceof Error ? err.message : "Could not fetch models";
      await writeLlmLog(uid, {
        level: "error",
        message: "Fetch models failed",
        detail: message,
        provider: typeof data.provider === "string" ? data.provider : stored.provider,
        source: "fetchLlmModels",
      });
      throw new HttpsError("failed-precondition", message);
    }
  },
);
