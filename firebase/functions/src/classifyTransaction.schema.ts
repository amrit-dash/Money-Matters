export interface PaymentSourceHint {
  id: string;
  displayName: string;
  type: string;
  senderHints?: string[];
  last4?: string | null;
}

export interface ClassifyRequest {
  merchant?: string | null;
  amount?: number | null;
  type?: string | null;
  smsBody?: string | null;
  sender?: string | null;
  categoryIds?: string[];
  selectedCategoryId?: string | null;
  hintCategoryId?: string | null;
  subcategoryTaxonomy?: Record<string, string[]>;
  paymentSources?: PaymentSourceHint[];
  /** User-typed description from Inbox classify (explicit confirmation path). */
  userDescription?: string | null;
}

/** Minimum model confidence before pipeline auto-applies category (else → Inbox). */
export const AUTO_APPLY_CATEGORY_CONFIDENCE = 0.8;

export function resolveSelectedCategory(data: ClassifyRequest): string | null {
  return trimOrNull(data.selectedCategoryId ?? undefined) ??
    trimOrNull(data.hintCategoryId ?? undefined);
}

export interface ClassifyResult {
  categoryId: string | null;
  merchantNormalized: string | null;
  subcategoryId: string | null;
  type: string | null;
  needsUserInput: boolean;
  needsConfig: boolean;
  categoryConfidence: number | null;
  paymentSourceId: string | null;
  paymentSourceConfidence: number | null;
  userNotes: string | null;
  shoppingItems: string[];
  travelProvider: string | null;
  transferTo: string | null;
  suggestedCategoryId: string | null;
  suggestedCategoryName: string | null;
}

function trimOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function formatSubcategoryTaxonomy(
  taxonomy: Record<string, string[]> | undefined,
): string {
  if (!taxonomy || Object.keys(taxonomy).length === 0) {
    return "(none — omit subcategoryId)";
  }
  return Object.entries(taxonomy)
    .map(([cat, subs]) => {
      const ids = (subs ?? []).filter(Boolean);
      if (ids.length === 0) return null;
      return `- ${cat}: ${ids.join(", ")}`;
    })
    .filter(Boolean)
    .join("\n");
}

export function buildPrompt(data: ClassifyRequest): string {
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

  const selected = resolveSelectedCategory(data);
  const subcategoryBlock = formatSubcategoryTaxonomy(data.subcategoryTaxonomy);

  const lines = [
    "You analyze a single Indian bank/UPI/credit-card SMS transaction.",
    "",
    "Pick the best categoryId from this allowed list ONLY:",
    allowed,
    "",
    "Optional subcategories (subcategoryId must match parent categoryId):",
    subcategoryBlock,
    "",
    "Saved payment accounts (banks/cards/wallets):",
    sourceLines,
    "",
    "Transaction:",
    `- parsed merchant: ${data.merchant ?? "unknown"}`,
    `- amount: ${data.amount ?? "unknown"}`,
    `- debit/credit: ${data.type ?? "debit"}`,
    `- SMS sender id: ${(data.sender ?? "").trim() || "unknown"}`,
    `- raw SMS: ${(data.smsBody ?? "").slice(0, 800)}`,
  ];

  const userDescription = trimOrNull(data.userDescription);
  if (userDescription) {
    lines.push(
      "",
      "User description (authoritative — they are confirming this spend):",
      userDescription,
      "Map their words to categoryId, subcategoryId, merchantNormalized, transferTo,",
      "shoppingItems, travelProvider, and paymentSourceId when mentioned.",
      "You MAY set userNotes from their description. Set needsUserInput false only",
      "when category and key fields are clear from their text.",
      "Set categoryConfidence 0.9+ when the user was explicit.",
    );
  }

  if (selected) {
    lines.push(
      "",
      `User pre-selected categoryId: ${selected}`,
      "The user already chose this category — return categoryId as this value.",
      "Still extract merchantNormalized, subcategoryId, transferTo, etc.",
      "Only override categoryId if the SMS clearly cannot be that category; " +
        "then set needsUserInput true.",
    );
  }

  lines.push(
    "",
    "Rules:",
    "- merchantNormalized: extract a clean human display name FROM THE SMS TEXT",
    "  (e.g. UPI 'paid to NIZAM M' → 'Nizam M', 'zepto-stores@ybl' → 'Zepto').",
    "  Prefer the payee/merchant name in the SMS over the parsed merchant field.",
    "- categoryId MUST be one of the allowed ids, or null if genuinely unclear.",
    "- categoryConfidence: 0.0–1.0 for how sure you are about categoryId.",
    `  Auto-apply only when >= ${AUTO_APPLY_CATEGORY_CONFIDENCE} AND needsUserInput false.`,
    "- If categoryId is null and no allowed category fits, set suggestedCategoryId",
    "  (lowercase slug) and suggestedCategoryName (human label) for a new category.",
    "- subcategoryId: pick from the subcategory list for the chosen categoryId when",
    "  applicable (e.g. groceries → quick_delivery for Zepto/Blinkit); null otherwise.",
    "- type: short spend kind (food, shopping, transfer, bills, ...).",
    "- needsUserInput: true when category is unclear OR this is a person-to-person",
    "  UPI payment (friend/family) — never guess food/lunch/shopping for P2P.",
    "- P2P / paid-to-a-person: set categoryId null, needsUserInput true,",
    "  categoryConfidence <= 0.5. Do NOT assign food, dining, or lunch.",
    "- Known merchants (Zepto, Swiggy, Amazon, Uber, etc.): category + subcategory",
    `  OK when categoryConfidence >= ${AUTO_APPLY_CATEGORY_CONFIDENCE}.`,
    "- paymentSourceId: pick an account id ONLY when the SMS clearly indicates that",
    "  account (sender id, bank name, card product, or last4). null if unclear.",
    "- paymentSourceConfidence: 0.0–1.0; use >= 0.85 only when very confident.",
    "- userNotes: null for automatic SMS-only classification (pipeline).",
    "  Only populate when userDescription is provided above.",
    "- shoppingItems: item names only for obvious grocery/shopping SMS or user text;",
    "  empty array otherwise.",
    "- travelProvider: ride/travel app when clear (Uber, Ola, Rapido, etc.); null otherwise.",
    "- transferTo: when categoryId is transfer, the person/account receiving funds",
    "  (from SMS payee name or merchantNormalized); null for non-transfers.",
  );

  return lines.join("\n");
}

const KNOWN_MERCHANT_KEYWORDS = [
  "zepto", "blinkit", "swiggy", "zomato", "amazon", "flipkart", "myntra",
  "uber", "ola", "rapido", "dmart", "bigbasket", "irctc", "makemytrip",
  "netflix", "spotify", "paytm", "phonepe", "gpay", "google pay",
];

/** Person-to-person UPI — never auto-categorize as food/shopping. */
export function isLikelyP2PPayment(data: ClassifyRequest): boolean {
  const merchant = (data.merchant ?? "").trim().toLowerCase();
  const body = (data.smsBody ?? "").trim().toLowerCase();
  const combined = `${merchant} ${body}`;

  if (/^p2[am]$/i.test((data.merchant ?? "").trim())) return true;
  if (/\bp2p\b|\bp2a\b|\bp2m\b/i.test(combined)) {
    if (!KNOWN_MERCHANT_KEYWORDS.some((k) => combined.includes(k))) {
      return true;
    }
  }
  if (merchant.includes("@") && !KNOWN_MERCHANT_KEYWORDS.some((k) => merchant.includes(k))) {
    return true;
  }
  if (/paid\s+to\s+[a-z][a-z\s]{1,40}(?:\s+via|\s+on|\s+upi|$)/i.test(body)) {
    const afterPaidTo = body.match(/paid\s+to\s+([a-z][a-z\s]{1,40})/i)?.[1] ?? "";
    const payee = afterPaidTo.trim();
    if (payee.length > 0 &&
        !KNOWN_MERCHANT_KEYWORDS.some((k) => payee.includes(k))) {
      return true;
    }
  }
  return false;
}

export const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    categoryId: {type: "STRING", nullable: true},
    merchantNormalized: {type: "STRING", nullable: true},
    subcategoryId: {type: "STRING", nullable: true},
    type: {type: "STRING", nullable: true},
    needsUserInput: {type: "BOOLEAN"},
    categoryConfidence: {type: "NUMBER", nullable: true},
    paymentSourceId: {type: "STRING", nullable: true},
    paymentSourceConfidence: {type: "NUMBER", nullable: true},
    userNotes: {type: "STRING", nullable: true},
    shoppingItems: {
      type: "ARRAY",
      items: {type: "STRING"},
    },
    travelProvider: {type: "STRING", nullable: true},
    transferTo: {type: "STRING", nullable: true},
    suggestedCategoryId: {type: "STRING", nullable: true},
    suggestedCategoryName: {type: "STRING", nullable: true},
  },
  required: ["needsUserInput"],
};

export function parseClassifyResponse(
  parsed: Record<string, unknown>,
  data: ClassifyRequest,
): ClassifyResult {
  const allowedCategories = new Set(data.categoryIds ?? []);
  const selectedCategory = resolveSelectedCategory(data);

  let categoryId = trimOrNull(parsed.categoryId);
  if (categoryId && allowedCategories.size > 0 && !allowedCategories.has(categoryId)) {
    categoryId = null;
  }

  const suggestedCategoryId = trimOrNull(parsed.suggestedCategoryId);
  const suggestedCategoryName = trimOrNull(parsed.suggestedCategoryName);

  if (selectedCategory &&
    (allowedCategories.size === 0 || allowedCategories.has(selectedCategory))) {
    const aiDisagrees =
      categoryId != null &&
      categoryId !== selectedCategory &&
      parsed.needsUserInput === true;
    if (!aiDisagrees) {
      categoryId = selectedCategory;
    }
  }

  const allowedSourceIds = new Set(
    (data.paymentSources ?? []).map((s) => s.id),
  );
  const rawSourceId = trimOrNull(parsed.paymentSourceId);
  const paymentSourceId =
    rawSourceId && allowedSourceIds.has(rawSourceId) ? rawSourceId : null;

  let paymentSourceConfidence: number | null = null;
  if (typeof parsed.paymentSourceConfidence === "number") {
    paymentSourceConfidence = parsed.paymentSourceConfidence;
  }

  let shoppingItems: string[] = [];
  if (Array.isArray(parsed.shoppingItems)) {
    shoppingItems = parsed.shoppingItems
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }

  const travelProvider = trimOrNull(parsed.travelProvider);
  const merchantNormalized = trimOrNull(parsed.merchantNormalized);

  let subcategoryId = trimOrNull(parsed.subcategoryId);
  const taxonomy = data.subcategoryTaxonomy ?? {};
  const effectiveCategory = categoryId ?? selectedCategory;
  if (subcategoryId && effectiveCategory) {
    const allowedSubs = taxonomy[effectiveCategory] ?? [];
    if (allowedSubs.length > 0 && !allowedSubs.includes(subcategoryId)) {
      subcategoryId = null;
    }
  } else if (!effectiveCategory) {
    subcategoryId = null;
  }

  let transferTo = trimOrNull(parsed.transferTo);
  if (!transferTo && categoryId === "transfer" && merchantNormalized) {
    transferTo = merchantNormalized;
  }

  let categoryConfidence: number | null = null;
  if (typeof parsed.categoryConfidence === "number") {
    categoryConfidence = parsed.categoryConfidence;
  }

  const userDescription = trimOrNull(data.userDescription);
  let userNotesOut = userDescription ? trimOrNull(parsed.userNotes) : null;

  let needsUserInput =
    categoryId === null ?
      true :
      parsed.needsUserInput === true;

  if (isLikelyP2PPayment(data) && !userDescription) {
    categoryId = null;
    subcategoryId = null;
    needsUserInput = true;
    categoryConfidence = categoryConfidence != null ?
      Math.min(categoryConfidence, 0.5) :
      0.3;
    userNotesOut = null;
  } else if (
    categoryId != null &&
    !userDescription &&
    !selectedCategory &&
    (categoryConfidence == null ||
      categoryConfidence < AUTO_APPLY_CATEGORY_CONFIDENCE)
  ) {
    categoryId = null;
    subcategoryId = null;
    needsUserInput = true;
  } else if (categoryId != null && !needsUserInput && !userDescription) {
    if (categoryConfidence == null) {
      categoryConfidence = 0.85;
    }
  }

  return {
    categoryId,
    merchantNormalized,
    subcategoryId,
    type: trimOrNull(parsed.type),
    needsUserInput,
    needsConfig: false,
    categoryConfidence,
    paymentSourceId,
    paymentSourceConfidence,
    userNotes: userNotesOut,
    shoppingItems,
    travelProvider,
    transferTo,
    suggestedCategoryId: categoryId === null ? suggestedCategoryId : null,
    suggestedCategoryName: categoryId === null ? suggestedCategoryName : null,
  };
}
