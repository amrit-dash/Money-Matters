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
}

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

  if (selected) {
    lines.push(
      "",
      `User pre-selected categoryId: ${selected}`,
      "The user already chose this category — return categoryId as this value.",
      "Still extract merchantNormalized, subcategoryId, transferTo, notes, etc.",
      "Only override categoryId if the SMS clearly cannot be that category; " +
        "then set needsUserInput true and explain briefly in userNotes.",
    );
  }

  lines.push(
    "",
    "Rules:",
    "- merchantNormalized: extract a clean human display name FROM THE SMS TEXT",
    "  (e.g. UPI 'paid to NIZAM M' → 'Nizam M', 'zepto-stores@ybl' → 'Zepto').",
    "  Prefer the payee/merchant name in the SMS over the parsed merchant field.",
    "- categoryId MUST be one of the allowed ids, or null if genuinely unclear.",
    "- If categoryId is null and no allowed category fits, set suggestedCategoryId",
    "  (lowercase slug) and suggestedCategoryName (human label) for a new category.",
    "- subcategoryId: pick from the subcategory list for the chosen categoryId when",
    "  applicable (e.g. bills → internet/rent/electricity); null otherwise.",
    "- type: short spend kind (food, shopping, transfer, bills, ...).",
    "- needsUserInput: true only if category cannot be determined confidently.",
    "- paymentSourceId: pick an account id ONLY when the SMS clearly indicates that",
    "  account (sender id, bank name, card product, or last4). null if unclear.",
    "- paymentSourceConfidence: 0.0–1.0; use >= 0.85 only when very confident.",
    "- userNotes: one short sentence on what this spend was for when inferable; null if unclear.",
    "- shoppingItems: item names only for obvious grocery/shopping SMS; empty array otherwise.",
    "- travelProvider: ride/travel app when clear (Uber, Ola, Rapido, etc.); null otherwise.",
    "- transferTo: when categoryId is transfer, the person/account receiving funds",
    "  (from SMS payee name or merchantNormalized); null for non-transfers.",
  );

  return lines.join("\n");
}

export const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    categoryId: {type: "STRING", nullable: true},
    merchantNormalized: {type: "STRING", nullable: true},
    subcategoryId: {type: "STRING", nullable: true},
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

  const userNotes = trimOrNull(parsed.userNotes);

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

  const needsUserInput =
    categoryId === null ?
      true :
      parsed.needsUserInput === true;

  return {
    categoryId,
    merchantNormalized,
    subcategoryId,
    type: trimOrNull(parsed.type),
    needsUserInput,
    needsConfig: false,
    paymentSourceId,
    paymentSourceConfidence,
    userNotes,
    shoppingItems,
    travelProvider,
    transferTo,
    suggestedCategoryId: categoryId === null ? suggestedCategoryId : null,
    suggestedCategoryName: categoryId === null ? suggestedCategoryName : null,
  };
}
