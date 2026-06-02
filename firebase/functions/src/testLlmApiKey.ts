import {onCall, HttpsError} from "firebase-functions/v2/https";

import {credentialsFromRequest, testProviderKey} from "./llm/providers";
import {writeLlmLog} from "./llm/llmLogs";
import {loadUserLlmConfig} from "./llm/userLlmConfig";

export const testLlmApiKey = onCall(
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
      await testProviderKey(creds);
      await writeLlmLog(uid, {
        level: "info",
        message: "API key verified",
        provider: creds.provider,
        model: creds.model,
        source: "testLlmApiKey",
      });
      return {ok: true};
    } catch (err) {
      const message = err instanceof Error ? err.message : "API key test failed";
      await writeLlmLog(uid, {
        level: "error",
        message: "API key test failed",
        detail: message,
        provider: typeof data.provider === "string" ? data.provider : stored.provider,
        source: "testLlmApiKey",
      });
      throw new HttpsError("failed-precondition", message);
    }
  },
);
