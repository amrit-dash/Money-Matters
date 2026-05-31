import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret, defineString} from "firebase-functions/params";
import {logger} from "firebase-functions";

// OpenRouter API key lives in a Functions secret, never in source. Set it with:
//   firebase functions:secrets:set OPENROUTER_API_KEY
// Optional model override (Functions param / env):
//   OPENROUTER_MODEL=meta-llama/llama-3.2-3b-instruct:free
// Default uses a free-tier slug — see docs/HANDOFF.md for alternatives.
// When the secret is absent the function returns {needsConfig: true} so the app
// falls back to its in-app "Needs your input" inbox instead of crashing.
const openrouterApiKey = defineSecret("OPENROUTER_API_KEY");
const openrouterModel = defineString("OPENROUTER_MODEL", {
  default: "google/gemma-2-9b-it:free",
});

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

interface ClassifyRequest {
  merchant?: string | null;
  amount?: number | null;
  type?: string | null;
  smsBody?: string | null;
  categoryIds?: string[];
}

export interface ClassifyResult {
  categoryId: string | null;
  merchantNormalized: string | null;
  type: string | null;
  needsUserInput: boolean;
  needsConfig: boolean;
}

function fallback(needsConfig: boolean): ClassifyResult {
  return {
    categoryId: null,
    merchantNormalized: null,
    type: null,
    needsUserInput: true,
    needsConfig,
  };
}

function buildPrompt(data: ClassifyRequest): string {
  const categoryIds = (data.categoryIds ?? []).filter((c) => !!c);
  const allowed = categoryIds.length > 0 ?
    categoryIds.join(", ") :
    "food, groceries, transport, shopping, bills, entertainment, health, " +
      "transfer, other";

  return [
    "You categorize a single Indian bank/UPI transaction.",
    "Pick the best categoryId from this allowed list ONLY:",
    allowed,
    "",
    "Transaction:",
    `- merchant: ${data.merchant ?? "unknown"}`,
    `- amount: ${data.amount ?? "unknown"}`,
    `- type: ${data.type ?? "debit"}`,
    `- raw SMS: ${(data.smsBody ?? "").slice(0, 600)}`,
    "",
    "Rules:",
    "- categoryId MUST be one of the allowed ids, or null if genuinely unclear.",
    "- merchantNormalized: a clean human name (e.g. 'zepto-stores@ybl' -> 'Zepto').",
    "- type: a short spend kind (food, shopping, transfer, bills, ...).",
    "- needsUserInput: true only if you cannot confidently categorize.",
    "",
    "Respond with JSON only, no markdown, matching this shape:",
    '{"categoryId": string|null, "merchantNormalized": string|null, "type": string|null, "needsUserInput": boolean}',
  ].join("\n");
}

async function callOpenRouter(
  key: string,
  model: string,
  data: ClassifyRequest,
): Promise<ClassifyResult> {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${key}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0.1,
      response_format: {type: "json_object"},
      messages: [
        {
          role: "user",
          content: buildPrompt(data),
        },
      ],
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    logger.error("OpenRouter call failed", {status: res.status, body, model});
    return fallback(false);
  }

  const json = (await res.json()) as {
    choices?: Array<{message?: {content?: string}}>;
  };
  const text = json.choices?.[0]?.message?.content;
  if (!text) return fallback(false);

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text) as Record<string, unknown>;
  } catch (err) {
    logger.error("OpenRouter returned non-JSON", {text, err});
    return fallback(false);
  }

  const allowed = new Set(data.categoryIds ?? []);
  const rawCategory =
    typeof parsed.categoryId === "string" ? parsed.categoryId : null;
  const categoryId =
    rawCategory && (allowed.size === 0 || allowed.has(rawCategory)) ?
      rawCategory :
      null;

  return {
    categoryId,
    merchantNormalized:
      typeof parsed.merchantNormalized === "string" ?
        parsed.merchantNormalized :
        null,
    type: typeof parsed.type === "string" ? parsed.type : null,
    needsUserInput:
      categoryId === null || parsed.needsUserInput === true,
    needsConfig: false,
  };
}

// Rules-first: the app only calls this for uncategorized/ambiguous spends.
// App Check is intentionally NOT enforced (parity with ingestSms path).
export const classifyTransaction = onCall(
  {
    region: "asia-south1",
    secrets: [openrouterApiKey],
    maxInstances: 5,
  },
  async (request): Promise<ClassifyResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }

    const key = openrouterApiKey.value();
    if (!key) {
      logger.warn("OPENROUTER_API_KEY not configured — returning needsConfig");
      return fallback(true);
    }

    const data = (request.data ?? {}) as ClassifyRequest;
    const model = openrouterModel.value();
    try {
      return await callOpenRouter(key, model, data);
    } catch (err) {
      logger.error("classifyTransaction error", err);
      return fallback(false);
    }
  },
);
