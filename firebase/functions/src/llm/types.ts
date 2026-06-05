export type LlmProviderId =
  | "gemini"
  | "openrouter"
  | "grok"
  | "groq"
  | "mistral"
  | "other";

export interface UserLlmConfig {
  enabled: boolean;
  provider: LlmProviderId;
  apiKey: string | null;
  model: string | null;
  baseUrl: string | null;
}

export interface LlmToolsRequest {
  provider?: string;
  apiKey?: string;
  model?: string;
  baseUrl?: string;
}

export const DEFAULT_MODELS: Record<LlmProviderId, string> = {
  gemini: "gemini-2.0-flash",
  openrouter: "google/gemini-2.0-flash-001",
  grok: "grok-4.3",
  groq: "llama-3.3-70b-versatile",
  mistral: "mistral-small-latest",
  other: "gpt-4o-mini",
};

export function parseProvider(raw: unknown): LlmProviderId | null {
  const value = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (
    value === "gemini" ||
    value === "openrouter" ||
    value === "grok" ||
    value === "groq" ||
    value === "mistral" ||
    value === "other"
  ) {
    return value;
  }
  return null;
}
