import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

// Gemini API key lives in a Functions secret, never in source. Set it with:
//   firebase functions:secrets:set GEMINI_API_KEY
// When the secret is absent the function returns {needsConfig: true} so the app
// falls back to its in-app "Needs your input" inbox instead of crashing.
const geminiApiKey = defineSecret("GEMINI_API_KEY");

const MODEL = "gemini-2.0-flash";
const ENDPOINT = (key: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`;

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
  ].join("\n");
}

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    categoryId: {type: "STRING", nullable: true},
    merchantNormalized: {type: "STRING", nullable: true},
    type: {type: "STRING", nullable: true},
    needsUserInput: {type: "BOOLEAN"},
  },
  required: ["needsUserInput"],
};

async function callGemini(
  key: string,
  data: ClassifyRequest,
): Promise<ClassifyResult> {
  const res = await fetch(ENDPOINT(key), {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents: [{role: "user", parts: [{text: buildPrompt(data)}]}],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    logger.error("Gemini call failed", {status: res.status, body});
    return fallback(false);
  }

  const json = (await res.json()) as {
    candidates?: Array<{content?: {parts?: Array<{text?: string}>}}>;
  };
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) return fallback(false);

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text) as Record<string, unknown>;
  } catch (err) {
    logger.error("Gemini returned non-JSON", {text, err});
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
    secrets: [geminiApiKey],
    maxInstances: 5,
  },
  async (request): Promise<ClassifyResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required");
    }

    const key = geminiApiKey.value();
    if (!key) {
      logger.warn("GEMINI_API_KEY not configured — returning needsConfig");
      return fallback(true);
    }

    const data = (request.data ?? {}) as ClassifyRequest;
    try {
      return await callGemini(key, data);
    } catch (err) {
      logger.error("classifyTransaction error", err);
      return fallback(false);
    }
  },
);
