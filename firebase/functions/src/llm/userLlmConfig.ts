import {getFirestore, Timestamp} from "firebase-admin/firestore";

import {
  DEFAULT_MODELS,
  type LlmProviderId,
  parseProvider,
  type UserLlmConfig,
} from "./types";

const SETTINGS_COLLECTION = "settings";
const LLM_DOC_ID = "llm";

export interface StoredUserLlmConfig extends UserLlmConfig {
  updatedAt: Timestamp | null;
}

export async function loadUserLlmConfig(uid: string): Promise<StoredUserLlmConfig> {
  const snap = await getFirestore()
    .collection("users")
    .doc(uid)
    .collection(SETTINGS_COLLECTION)
    .doc(LLM_DOC_ID)
    .get();

  if (!snap.exists) {
    return emptyConfig();
  }

  const data = snap.data() ?? {};
  const provider = parseProvider(data.provider) ?? "gemini";
  const apiKey = trimOrNull(data.apiKey);
  const model = trimOrNull(data.model) ?? DEFAULT_MODELS[provider];

  return {
    enabled: data.enabled === true,
    provider,
    apiKey,
    model,
    baseUrl: trimOrNull(data.baseUrl),
    updatedAt: data.updatedAt instanceof Timestamp ? data.updatedAt : null,
  };
}

export function emptyConfig(): StoredUserLlmConfig {
  return {
    enabled: false,
    provider: "gemini",
    apiKey: null,
    model: DEFAULT_MODELS.gemini,
    baseUrl: null,
    updatedAt: null,
  };
}

export function resolveRuntimeConfig(
  stored: StoredUserLlmConfig,
  fallbackGeminiKey: string | undefined,
): UserLlmConfig & {resolvedKey: string | null} {
  if (stored.enabled && stored.apiKey) {
    return {...stored, resolvedKey: stored.apiKey};
  }
  if (stored.enabled && fallbackGeminiKey && stored.provider === "gemini") {
    return {
      ...stored,
      apiKey: fallbackGeminiKey,
      resolvedKey: fallbackGeminiKey,
    };
  }
  if (!stored.enabled && fallbackGeminiKey) {
    return {
      enabled: true,
      provider: "gemini",
      apiKey: fallbackGeminiKey,
      model: stored.model ?? DEFAULT_MODELS.gemini,
      baseUrl: null,
      resolvedKey: fallbackGeminiKey,
    };
  }
  return {...stored, resolvedKey: null};
}

function trimOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function providerLabel(provider: LlmProviderId): string {
  switch (provider) {
  case "gemini":
    return "Gemini";
  case "openrouter":
    return "Open Router";
  case "grok":
    return "Grok";
  case "mistral":
    return "Mistral";
  default:
    return "Other";
  }
}
