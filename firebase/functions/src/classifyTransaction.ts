import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {classifyWithProvider, type ProviderCredentials} from "./llm/providers";
import {writeLlmLog} from "./llm/llmLogs";
import {loadUserLlmConfig} from "./llm/userLlmConfig";
import {DEFAULT_MODELS} from "./llm/types";
import {
  type ClassifyRequest,
  type ClassifyResult,
} from "./classifyTransaction.schema";

export {
  buildPrompt,
  parseClassifyResponse,
  resolveSelectedCategory,
  RESPONSE_SCHEMA,
  type ClassifyRequest,
  type ClassifyResult,
} from "./classifyTransaction.schema";

const geminiApiKey = defineSecret("GEMINI_API_KEY");

interface RuntimeLlm {
  creds: ProviderCredentials;
}

async function resolveRuntimeLlm(
  uid: string,
  legacyGeminiKey: string | undefined,
): Promise<RuntimeLlm | null> {
  const stored = await loadUserLlmConfig(uid);
  const docExists = await userLlmDocExists(uid);

  if (docExists) {
    if (!stored.enabled) return null;
    if (!stored.apiKey) return null;
    return {
      creds: {
        provider: stored.provider,
        apiKey: stored.apiKey,
        model: stored.model ?? DEFAULT_MODELS[stored.provider],
        baseUrl: stored.baseUrl,
      },
    };
  }

  if (legacyGeminiKey) {
    return {
      creds: {
        provider: "gemini",
        apiKey: legacyGeminiKey,
        model: DEFAULT_MODELS.gemini,
        baseUrl: null,
      },
    };
  }

  return null;
}

async function userLlmDocExists(uid: string): Promise<boolean> {
  const snap = await getFirestore()
    .collection("users")
    .doc(uid)
    .collection("settings")
    .doc("llm")
    .get();
  return snap.exists;
}

function fallback(needsConfig: boolean): ClassifyResult {
  return {
    categoryId: null,
    subcategoryId: null,
    merchantNormalized: null,
    type: null,
    needsUserInput: true,
    needsConfig,
    paymentSourceId: null,
    paymentSourceConfidence: null,
    userNotes: null,
    shoppingItems: [],
    travelProvider: null,
    transferTo: null,
    suggestedCategoryId: null,
    suggestedCategoryName: null,
  };
}

export const classifyTransaction = onCall(
  {
    region: "asia-south1",
    secrets: [geminiApiKey],
    maxInstances: 5,
  },
  async (request): Promise<ClassifyResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }

    const uid = request.auth.uid;
    const data = (request.data ?? {}) as ClassifyRequest;
    const legacyKey = geminiApiKey.value();
    const runtime = await resolveRuntimeLlm(uid, legacyKey);

    if (!runtime) {
      const stored = await loadUserLlmConfig(uid);
      const docExists = await userLlmDocExists(uid);
      const reason = stored.enabled && !stored.apiKey ?
        "LLM enabled but API key missing" :
        docExists && !stored.enabled ?
          "LLM disabled in Agent settings" :
          "LLM not configured";
      logger.warn("classifyTransaction needsConfig", {uid, reason});
      await writeLlmLog(uid, {
        level: "warn",
        message: reason,
        source: "classifyTransaction",
        provider: stored.provider,
        model: stored.model,
      });
      return fallback(true);
    }

    try {
      const result = await classifyWithProvider(runtime.creds, data);
      if (result.categoryId != null && !result.needsUserInput) {
        await writeLlmLog(uid, {
          level: "info",
          message: "Classify succeeded",
          provider: runtime.creds.provider,
          model: runtime.creds.model,
          source: "classifyTransaction",
        });
      }
      return result;
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      logger.error("classifyTransaction error", err);
      await writeLlmLog(uid, {
        level: "error",
        message: "Classify failed",
        detail,
        provider: runtime.creds.provider,
        model: runtime.creds.model,
        source: "classifyTransaction",
      });
      return fallback(false);
    }
  },
);
