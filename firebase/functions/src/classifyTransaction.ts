import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

// Gemini API key lives in a Functions secret, never in source. Set it with:
//   firebase functions:secrets:set GEMINI_API_KEY
// Get a key at https://aistudio.google.com/apikey — NEVER paste keys in chat/Cursor.
// When the secret is absent the function returns {needsConfig: true} so the app
// falls back to its in-app "Needs your input" inbox instead of crashing.
const geminiApiKey = defineSecret("GEMINI_API_KEY");

const MODEL = "gemini-2.0-flash";
const ENDPOINT = (key: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`;

interface PaymentSourceHint {
  id: string;
  displayName: string;
  type: string;
  senderHints?: string[];
  last4?: string | null;
}

interface ClassifyRequest {
  merchant?: string | null;
  amount?: number | null;
  type?: string | null;
  smsBody?: string | null;
  sender?: string | null;
  categoryIds?: string[];
  paymentSources?: PaymentSourceHint[];
}

export interface ClassifyResult {
  categoryId: string | null;
  merchantNormalized: string | null;
  type: string | null;
  needsUserInput: boolean;
  needsConfig: boolean;
  paymentSourceId: string | null;
  paymentSourceConfidence: number | null;
  userNotes: string | null;
  shoppingItems: string[];
  travelProvider: string | null;
}

function fallback(needsConfig: boolean): ClassifyResult {
  return {
    categoryId: null,
    merchantNormalized: null,
    type: null,
    needsUserInput: true,
    needsConfig,
    paymentSourceId: null,
    paymentSourceConfidence: null,
    userNotes: null,
    shoppingItems: [],
    travelProvider: null,
  };
}

function buildPrompt(data: ClassifyRequest): string {
  const categoryIds = (data.categoryIds ?? []).filter((c) => !!c);
  const allowed = categoryIds.length > 0 ?
    categoryIds.join(", ") :
    "groceries, food, transport, shopping, bills, subscriptions, " +
      "entertainment, health, travel, education, savings, income, transfer, " +
      "fees, gifts, personal, other";

  const sources = data.paymentSources ?? [];
  const sourceLines = sources.length > 0 ?
    sources.map((s) => {
      const hints = (s.senderHints ?? []).filter(Boolean).join(", ") || "none";
      const last4 = s.last4 ? ` · last4 ${s.last4}` : "";
      return `- id=${s.id} · ${s.displayName} (${s.type}) · senderHints: ${hints}${last4}`;
    }).join("\n") :
    "(none — skip payment source assignment)";

  return [
    "You analyze a single Indian bank/UPI/credit-card SMS transaction.",
    "",
    "Pick the best categoryId from this allowed list ONLY:",
    allowed,
    "",
    "Saved payment accounts (banks/cards/wallets):",
    sourceLines,
    "",
    "Transaction:",
    `- merchant: ${data.merchant ?? "unknown"}`,
    `- amount: ${data.amount ?? "unknown"}`,
    `- type: ${data.type ?? "debit"}`,
    `- SMS sender id: ${(data.sender ?? "").trim() || "unknown"}`,
    `- raw SMS: ${(data.smsBody ?? "").slice(0, 800)}`,
    "",
    "Rules:",
    "- categoryId MUST be one of the allowed ids, or null if genuinely unclear.",
    "- merchantNormalized: a clean human name (e.g. 'zepto-stores@ybl' -> 'Zepto').",
    "- type: a short spend kind (food, shopping, transfer, bills, ...).",
    "- needsUserInput: true only if you cannot confidently categorize.",
    "- paymentSourceId: pick an account id ONLY when the SMS clearly indicates that",
    "  account (SMS sender id like FEDBNK-S / FEDSCP-S, bank name in footer, card",
    "  product name, or last4). Match sender id to senderHints first. null if unclear.",
    "- paymentSourceConfidence: 0.0–1.0; use >= 0.85 only when very confident.",
    "- userNotes: one short sentence on what this spend was for when you can infer it",
    "  from the SMS (e.g. 'Uber ride to airport'); null if unclear.",
    "- shoppingItems: array of item names only for obvious grocery/shopping SMS;",
    "  empty array otherwise.",
    "- travelProvider: ride/travel app when clear from SMS (Uber, Ola, Rapido, etc.);",
    "  null if unclear or not a ride/travel spend.",
  ].join("\n");
}

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    categoryId: {type: "STRING", nullable: true},
    merchantNormalized: {type: "STRING", nullable: true},
    type: {type: "STRING", nullable: true},
    needsUserInput: {type: "BOOLEAN"},
    paymentSourceId: {type: "STRING", nullable: true},
    paymentSourceConfidence: {type: "NUMBER", nullable: true},
    userNotes: {type: "STRING", nullable: true},
    shoppingItems: {
      type: "ARRAY",
      items: {type: "STRING"},
    },
    travelProvider: {type: "STRING", nullable: true},
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

  const allowedCategories = new Set(data.categoryIds ?? []);
  const rawCategory =
    typeof parsed.categoryId === "string" ? parsed.categoryId : null;
  const categoryId =
    rawCategory && (allowedCategories.size === 0 || allowedCategories.has(rawCategory)) ?
      rawCategory :
      null;

  const allowedSourceIds = new Set(
    (data.paymentSources ?? []).map((s) => s.id),
  );
  const rawSourceId =
    typeof parsed.paymentSourceId === "string" ? parsed.paymentSourceId : null;
  const paymentSourceId =
    rawSourceId && allowedSourceIds.has(rawSourceId) ?
      rawSourceId :
      null;

  let paymentSourceConfidence: number | null = null;
  if (typeof parsed.paymentSourceConfidence === "number") {
    paymentSourceConfidence = parsed.paymentSourceConfidence;
  }

  const rawNotes =
    typeof parsed.userNotes === "string" ? parsed.userNotes.trim() : "";
  const userNotes = rawNotes.length > 0 ? rawNotes : null;

  let shoppingItems: string[] = [];
  if (Array.isArray(parsed.shoppingItems)) {
    shoppingItems = parsed.shoppingItems
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }

  const rawTravel =
    typeof parsed.travelProvider === "string" ? parsed.travelProvider.trim() : "";
  const travelProvider = rawTravel.length > 0 ? rawTravel : null;

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
    paymentSourceId,
    paymentSourceConfidence,
    userNotes,
    shoppingItems,
    travelProvider,
  };
}

// Rules-first: the app only calls this for uncategorized/ambiguous spends and
// unmatched payment-source assignment. App Check is intentionally NOT enforced.
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
