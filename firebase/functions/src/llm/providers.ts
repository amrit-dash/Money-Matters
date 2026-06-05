import {logger} from "firebase-functions";

import {
  RESPONSE_SCHEMA,
  buildPrompt,
  parseClassifyResponse,
  type ClassifyRequest,
  type ClassifyResult,
} from "../classifyTransaction.schema";
import {
  resolveApiKeyForProvider,
  resolveModelForProvider,
  type StoredUserLlmConfig,
} from "./userLlmConfig";
import {
  DEFAULT_MODELS,
  type LlmProviderId,
  parseProvider,
} from "./types";

export interface ProviderCredentials {
  provider: LlmProviderId;
  apiKey: string;
  model: string;
  baseUrl?: string | null;
}

export async function testProviderKey(creds: ProviderCredentials): Promise<void> {
  switch (creds.provider) {
  case "gemini":
    await pingGemini(creds.apiKey, creds.model);
    return;
  default:
    await pingOpenAiCompatible(creds);
  }
}

export async function fetchProviderModels(
  creds: ProviderCredentials,
): Promise<string[]> {
  switch (creds.provider) {
  case "gemini":
    return fetchGeminiModels(creds.apiKey);
  case "openrouter":
    return fetchOpenAiCompatibleModels(
      "https://openrouter.ai/api/v1/models",
      creds.apiKey,
      {
        "HTTP-Referer": "https://money-matters.app",
        "X-Title": "Money Matters",
      },
    );
  case "grok": {
    const models = await fetchOpenAiCompatibleModels(
      "https://api.x.ai/v1/models",
      creds.apiKey,
    );
    return filterGrokChatModelIds(models);
  }
  case "groq":
    return fetchOpenAiCompatibleModels(
      "https://api.groq.com/openai/v1/models",
      creds.apiKey,
    );
  case "mistral":
    return fetchOpenAiCompatibleModels(
      "https://api.mistral.ai/v1/models",
      creds.apiKey,
    );
  case "other": {
    const base = normalizeBaseUrl(creds.baseUrl);
    return fetchOpenAiCompatibleModels(`${base}/v1/models`, creds.apiKey);
  }
  default:
    throw new Error(`Unsupported provider: ${creds.provider}`);
  }
}

export async function classifyWithProvider(
  creds: ProviderCredentials,
  data: ClassifyRequest,
): Promise<ClassifyResult> {
  switch (creds.provider) {
  case "gemini":
    return callGemini(creds.apiKey, creds.model, data);
  default:
    return callOpenAiCompatible(creds, data);
  }
}

export function credentialsFromRequest(
  data: Record<string, unknown>,
  stored?: StoredUserLlmConfig,
): ProviderCredentials {
  const provider = parseProvider(data.provider) ??
    stored?.provider ??
    "gemini";
  const apiKey = stored ?
    resolveApiKeyForProvider(provider, data.apiKey, stored) :
    trimOrNull(data.apiKey);
  if (!apiKey) {
    throw new Error("API key is required");
  }
  const model = trimOrNull(data.model) ??
    (stored ? resolveModelForProvider(provider, stored.models, stored.model) : null) ??
    DEFAULT_MODELS[provider];
  const baseUrl = trimOrNull(data.baseUrl) ?? stored?.baseUrl ?? null;
  return {provider, apiKey, model, baseUrl};
}

function trimOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeBaseUrl(raw: string | null | undefined): string {
  const trimmed = (raw ?? "").trim().replace(/\/+$/, "");
  if (!trimmed) {
    throw new Error("Base URL is required for Other provider");
  }
  if (!/^https?:\/\//i.test(trimmed)) {
    throw new Error("Base URL must start with http:// or https://");
  }
  return trimmed;
}

async function pingGemini(apiKey: string, model: string): Promise<void> {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents: [{role: "user", parts: [{text: "Reply with OK"}]}],
      generationConfig: {maxOutputTokens: 8, temperature: 0},
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini key test failed (${res.status}): ${body.slice(0, 200)}`);
  }
}

async function pingOpenAiCompatible(creds: ProviderCredentials): Promise<void> {
  if (creds.provider === "grok") {
    await pingGrokChat(creds);
    return;
  }
  const res = await fetch(modelsListUrl(creds), {
    headers: {
      Authorization: `Bearer ${creds.apiKey}`,
      ...(creds.provider === "openrouter" ?
        {"HTTP-Referer": "https://money-matters.app", "X-Title": "Money Matters"} :
        {}),
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(
      `${creds.provider} key test failed (${res.status}): ${body.slice(0, 200)}`,
    );
  }
}

/** Grok keys can list models but fail classify when the budget is too small for reasoning. */
async function pingGrokChat(creds: ProviderCredentials): Promise<void> {
  const res = await fetch(chatCompletionsUrl(creds), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${creds.apiKey}`,
    },
    body: JSON.stringify({
      model: creds.model,
      temperature: 0,
      max_completion_tokens: 16,
      reasoning_effort: "low",
      messages: [{role: "user", content: "Reply with OK"}],
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`grok key test failed (${res.status}): ${body.slice(0, 200)}`);
  }
}

async function fetchGeminiModels(apiKey: string): Promise<string[]> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini models failed (${res.status}): ${body.slice(0, 200)}`);
  }
  const json = (await res.json()) as {models?: Array<{name?: string}>};
  return (json.models ?? [])
    .map((m) => (m.name ?? "").replace(/^models\//, ""))
    .filter((name) => name.includes("gemini") || name.includes("flash"))
    .sort();
}

async function fetchOpenAiCompatibleModels(
  url: string,
  apiKey: string,
  extraHeaders: Record<string, string> = {},
): Promise<string[]> {
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      ...extraHeaders,
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Models request failed (${res.status}): ${body.slice(0, 200)}`);
  }
  const json = (await res.json()) as {data?: Array<{id?: string}>};
  return (json.data ?? [])
    .map((m) => m.id ?? "")
    .filter(Boolean)
    .sort();
}

async function callGemini(
  key: string,
  model: string,
  data: ClassifyRequest,
): Promise<ClassifyResult> {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents: [{role: "user", parts: [{text: buildPrompt(data)}]}],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 512,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    logger.error("Gemini call failed", {status: res.status, body});
    throw new Error(`Gemini classify failed (${res.status})`);
  }

  const json = (await res.json()) as {
    candidates?: Array<{content?: {parts?: Array<{text?: string}>}}>;
  };
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini returned empty response");
  }

  const parsed = JSON.parse(text) as Record<string, unknown>;
  return parseClassifyResponse(parsed, data);
}

/** Exported for unit tests. */
export function buildOpenAiCompatibleClassifyBody(
  creds: ProviderCredentials,
  data: ClassifyRequest,
): Record<string, unknown> {
  const schemaHint = JSON.stringify(RESPONSE_SCHEMA);
  const messages = [
    {
      role: "system",
      content:
        "You classify Indian bank SMS transactions. Respond with JSON only matching this schema: " +
        schemaHint,
    },
    {role: "user", content: buildPrompt(data)},
  ];
  const base = {
    model: creds.model,
    temperature: 0.1,
    response_format: {type: "json_object"},
    messages,
  };
  if (creds.provider === "grok") {
    return {
      ...base,
      max_completion_tokens: 2048,
      reasoning_effort: "low",
    };
  }
  return {...base, max_tokens: 512};
}

/** Keep chat-capable Grok models; image/embedding ids fail on /chat/completions. */
export function filterGrokChatModelIds(ids: string[]): string[] {
  return ids.filter((id) => {
    const lower = id.toLowerCase();
    if (!lower.startsWith("grok")) return false;
    if (
      lower.includes("vision") ||
      lower.includes("image") ||
      lower.includes("embed")
    ) {
      return false;
    }
    return true;
  });
}

async function callOpenAiCompatible(
  creds: ProviderCredentials,
  data: ClassifyRequest,
): Promise<ClassifyResult> {
  const chatUrl = chatCompletionsUrl(creds);
  const res = await fetch(chatUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${creds.apiKey}`,
      ...(creds.provider === "openrouter" ?
        {"HTTP-Referer": "https://money-matters.app", "X-Title": "Money Matters"} :
        {}),
    },
    body: JSON.stringify(buildOpenAiCompatibleClassifyBody(creds, data)),
  });

  if (!res.ok) {
    const body = await res.text();
    logger.error("OpenAI-compatible classify failed", {
      provider: creds.provider,
      status: res.status,
      body,
    });
    throw new Error(
      `${creds.provider} classify failed (${res.status}): ${body.slice(0, 200)}`,
    );
  }

  const json = (await res.json()) as {
    choices?: Array<{
      message?: {content?: string | null};
      finish_reason?: string | null;
    }>;
  };
  const choice = json.choices?.[0];
  const text = choice?.message?.content;
  if (!text) {
    const reason = choice?.finish_reason ?? "unknown";
    throw new Error(
      `${creds.provider} returned empty response (finish_reason=${reason})`,
    );
  }

  const parsed = JSON.parse(text) as Record<string, unknown>;
  return parseClassifyResponse(parsed, data);
}

function chatCompletionsUrl(creds: ProviderCredentials): string {
  switch (creds.provider) {
  case "openrouter":
    return "https://openrouter.ai/api/v1/chat/completions";
  case "grok":
    return "https://api.x.ai/v1/chat/completions";
  case "groq":
    return "https://api.groq.com/openai/v1/chat/completions";
  case "mistral":
    return "https://api.mistral.ai/v1/chat/completions";
  case "other":
    return `${normalizeBaseUrl(creds.baseUrl)}/v1/chat/completions`;
  default:
    throw new Error(`No chat URL for ${creds.provider}`);
  }
}

function modelsListUrl(creds: ProviderCredentials): string {
  switch (creds.provider) {
  case "openrouter":
    return "https://openrouter.ai/api/v1/models";
  case "grok":
    return "https://api.x.ai/v1/models";
  case "groq":
    return "https://api.groq.com/openai/v1/models";
  case "mistral":
    return "https://api.mistral.ai/v1/models";
  case "other":
    return `${normalizeBaseUrl(creds.baseUrl)}/v1/models`;
  default:
    throw new Error(`No models URL for ${creds.provider}`);
  }
}
