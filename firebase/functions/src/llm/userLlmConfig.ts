import {getFirestore, Timestamp} from "firebase-admin/firestore";

import {
  DEFAULT_MODELS,
  type LlmProviderId,
  parseProvider,
  type UserLlmConfig,
} from "./types";

const SETTINGS_COLLECTION = "settings";
const LLM_DOC_ID = "llm";

export type ApiKeysByProvider = Partial<Record<LlmProviderId, string>>;
export type ModelsByProvider = Partial<Record<LlmProviderId, string>>;

export interface StoredUserLlmConfig extends UserLlmConfig {
  apiKeys: ApiKeysByProvider;
  models: ModelsByProvider;
  updatedAt: Timestamp | null;
}

export interface LoadedUserLlmConfig {
  stored: StoredUserLlmConfig;
  docExists: boolean;
}

export async function loadUserLlmConfig(uid: string): Promise<StoredUserLlmConfig> {
  const {stored} = await loadUserLlmConfigWithMeta(uid);
  return stored;
}

export async function loadUserLlmConfigWithMeta(
  uid: string,
): Promise<LoadedUserLlmConfig> {
  const snap = await getFirestore()
    .collection("users")
    .doc(uid)
    .collection(SETTINGS_COLLECTION)
    .doc(LLM_DOC_ID)
    .get();

  if (!snap.exists) {
    return {stored: emptyConfig(), docExists: false};
  }

  const data = snap.data() ?? {};
  const provider = parseProvider(data.provider) ?? "gemini";
  let apiKeys = parseApiKeys(data.apiKeys);
  const legacyKey = trimOrNull(data.apiKey);
  if (legacyKey && !apiKeys[provider]) {
    apiKeys = {...apiKeys, [provider]: legacyKey};
  }
  let models = parseModelsMap(data.models);
  const legacyModel = trimOrNull(data.model);
  if (legacyModel && !models[provider]) {
    models = {...models, [provider]: legacyModel};
  }
  const model = resolveModelForProvider(provider, models, legacyModel);

  return {
    stored: {
      enabled: data.enabled === true,
      provider,
      apiKeys,
      models,
      apiKey: apiKeys[provider] ?? null,
      model,
      baseUrl: trimOrNull(data.baseUrl),
      updatedAt: data.updatedAt instanceof Timestamp ? data.updatedAt : null,
    },
    docExists: true,
  };
}

export function emptyConfig(): StoredUserLlmConfig {
  return {
    enabled: false,
    provider: "gemini",
    apiKeys: {},
    models: {},
    apiKey: null,
    model: DEFAULT_MODELS.gemini,
    baseUrl: null,
    updatedAt: null,
  };
}

/** Inline request key wins; stored keys are scoped per provider. */
export function resolveApiKeyForProvider(
  provider: LlmProviderId,
  inline: unknown,
  stored: Pick<StoredUserLlmConfig, "apiKeys" | "apiKey" | "provider">,
): string | null {
  const fromRequest = trimOrNull(inline);
  if (fromRequest) return fromRequest;
  const fromMap = stored.apiKeys[provider];
  if (fromMap) return fromMap;
  if (stored.apiKey && stored.provider === provider) {
    return stored.apiKey;
  }
  return null;
}

export function resolveRuntimeConfig(
  stored: StoredUserLlmConfig,
  fallbackGeminiKey: string | undefined,
): UserLlmConfig & {resolvedKey: string | null} {
  const activeKey = resolveApiKeyForProvider(stored.provider, null, stored);
  if (stored.enabled && activeKey) {
    return {...stored, apiKey: activeKey, resolvedKey: activeKey};
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
  return {...stored, apiKey: activeKey, resolvedKey: null};
}

export function resolveModelForProvider(
  provider: LlmProviderId,
  models: ModelsByProvider,
  legacyModel?: string | null,
): string {
  const fromMap = models[provider];
  if (fromMap) return fromMap;
  const legacy = trimOrNull(legacyModel);
  if (legacy) return legacy;
  return DEFAULT_MODELS[provider];
}

function parseModelsMap(raw: unknown): ModelsByProvider {
  if (!raw || typeof raw !== "object") return {};
  const out: ModelsByProvider = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const provider = parseProvider(key);
    const model = trimOrNull(value);
    if (provider && model) out[provider] = model;
  }
  return out;
}

function parseApiKeys(raw: unknown): ApiKeysByProvider {
  if (!raw || typeof raw !== "object") return {};
  const out: ApiKeysByProvider = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const provider = parseProvider(key);
    const apiKey = trimOrNull(value);
    if (provider && apiKey) out[provider] = apiKey;
  }
  return out;
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
