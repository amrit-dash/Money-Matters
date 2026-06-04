import {
  ParseResult,
  ParsedTransactionCandidate,
  RawIngestInput,
  TransactionType,
} from "./types";

const RULES_VERSION = "1.0.0";

const AMOUNT_PATTERN = /(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)/i;

const LAST4_PATTERN =
  /\*\*(\d{4})|(?:ending|ends)\s+(?:with\s+)?(?:\*{1,2}|X{1,4})*(\d{4})|(?:A[/\\]c|Acct|Account)\.?\s*(?:no\.?\s*)?(?:\*{1,2}|X{1,4})*(\d{4})|(?:Card|card)\s+(?:no\.?\s*)?(?:\*{1,2}|X{1,4})*(\d{4})|Acct\s+XX(\d{3,4})|(?:wallet)\s+(?:XX)?(\d{4})/i;

const MERCHANT_AT_PATTERN =
  /\bat\s+([A-Z0-9][A-Z0-9\s&\-.]{1,40}?)\s+on\b/i;

const MERCHANT_COLON_PATTERN =
  /Merchant:\s*([A-Za-z0-9][A-Za-z0-9\s&\-.]{1,40}?)(?:\.|;|\s+Avl|\s*$)/i;

const UPI_MASKED_NAME_PATTERN = /UPI\/.+?\*\*([^*\n]{2,60}?)\*\*/i;

const UPI_FULL_PATH_PATTERN = /UPI\/(.+?)(?:\s+on\s|\.\s|$)/i;

const UPI_TYPE_CODES = new Set([
  "P2A", "P2M", "P2P", "PAY", "COLLECT", "INTENT", "MANDATE",
]);

const UPI_PROVIDER_SUFFIXES = new Set([
  "PAYTM", "YBL", "OKAXIS", "OKICICI", "OKHDFCBANK", "OKSBI",
  "AXL", "IBL", "APL", "UPI",
]);

const FEDERAL_SENT_UPI_PATTERN =
  /sent via UPI on .+? to ([\w.\-]+@[\w.\-]*?)(?=[\s,.]|$)/i;

const UPI_TO_VPA_PATTERN = /\bto\s+([\w.\-]+@[\w.\-]*?)(?=[\s,.]|$)/i;

const UPI_PATTERN =
  /(?:paid|sent)\s+(?:to\s+)?(?!via\b)([A-Z][A-Z\s]{2,30})(?:\s+via|\s+on|\s+using|\s*$)/i;

const TIME_PATTERN = /\bat\s+(\d{2}:\d{2}(?::\d{2})?)\b/;

const DATE_PATTERN = /(\d{1,2}[-/](?:\d{1,2}|[A-Za-z]{3})[-/]\d{2,4})/;

const REMINDER_PATTERNS = [
  /bill\s+due/i,
  /payment\s+due/i,
  /minimum\s+due/i,
  /\bmin\.?\s+due/i,
  /due\s+on/i,
  /statement\s+generated/i,
  /pay\s+by/i,
  /emi\s+due/i,
  /total\s+amount\s+due/i,
];

const HARD_PROMO_PATTERNS = [
  /pre[\s-]?approved/i,
  /\bapply\s+now\b/i,
  /eligible\s+for/i,
  /you\s+are\s+eligible/i,
  /loan\s+offer/i,
  /personal\s+loan/i,
  /instant\s+loan/i,
  /business\s+loan/i,
  /\bloan\s+up\s*to\b/i,
  /\bget\s+a\s+loan\b/i,
  /emi\s+offer/i,
  /limited\s+time/i,
  /lowest\s+interest/i,
  /interest\s+rate/i,
  /click\s+here/i,
  /t&c\s*apply/i,
  /\bredeem\b/i,
  /reward\s+points/i,
  /cashback\s+offer/i,
  /download\s+(?:our\s+)?app/i,
  /\bcongratulations\b/i,
  /missed\s+call/i,
  /offer\s+valid/i,
  /\bhurry\b/i,
];

const PROMO_PATTERNS = [
  /\boffer\b/i,
  /\bdiscount\b/i,
  /\bsale\b/i,
  /\bwin\b/i,
];

const INSTRUMENT_CONTEXT_PATTERN =
  /\bA\/c\b|\bAcct?\b|\baccount\b|\bcard\b|\bUPI\b|\bwallet\b|\bVPA\b|\*\*\d|ending\s+\d|\bx{2,}\d/i;

const DEBIT_PATTERNS = [
  /\bdebited\b/i,
  /\bspent\b/i,
  /\bpaid\b/i,
  /\bsent\b/i,
  /\bwithdrawn\b/i,
  /\bpurchase\b/i,
  /\btxn\s+of\b/i,
  /using\b[\w\s]*\bcard\b/i,
  /\bdr\b/i,
];

const CREDIT_PATTERNS = [
  /\bcredited\b/i,
  /\breceived\b/i,
  /\brefund\b/i,
  /\bcr\b/i,
];

const KNOWN_BRANDS = new Set([
  "SWIGGY", "ZOMATO", "ZUDIO", "AMAZON", "FLIPKART",
  "BIGBASKET", "ZEPTO", "BLINKIT",
]);

function matchesAny(body: string, patterns: RegExp[]): boolean {
  return patterns.some((p) => p.test(body));
}

function hasStrongTransactionSignal(body: string): boolean {
  return matchesAny(body, DEBIT_PATTERNS) || matchesAny(body, CREDIT_PATTERNS);
}

function extractAmount(body: string): number | null {
  const match = AMOUNT_PATTERN.exec(body);
  if (!match?.[1]) return null;
  const raw = match[1].replace(/,/g, "");
  const value = Number.parseFloat(raw);
  return Number.isFinite(value) ? value : null;
}

function extractType(body: string): TransactionType {
  const hasCredit = matchesAny(body, CREDIT_PATTERNS);
  const hasDebit = matchesAny(body, DEBIT_PATTERNS);
  if (hasCredit && !hasDebit) return "credit";
  return "debit";
}

export function extractInstrumentLast4(body: string): string | null {
  const match = LAST4_PATTERN.exec(body);
  if (!match) return null;
  for (let i = 1; i <= match.length; i++) {
    const group = match[i];
    if (group && group.length > 0) {
      return group.length === 3 ? group.padStart(4, "0") : group;
    }
  }
  return null;
}

function cleanMerchant(raw: string): string {
  return raw.trim().replace(/\s+/g, " ").toUpperCase();
}

function normalizeVpa(raw: string): string {
  let vpa = raw.trim();
  if (vpa.endsWith(".")) {
    vpa = vpa.slice(0, -1);
  }
  return vpa;
}

function cleanVpaMerchant(raw: string): string {
  return normalizeVpa(raw).toUpperCase();
}

function extractMerchantFromUpiPath(body: string): string | null {
  if (!/\bUPI\b/i.test(body)) return null;

  const masked = UPI_MASKED_NAME_PATTERN.exec(body);
  if (masked?.[1]) {
    const name = masked[1].trim();
    if (name.length > 0 && /[A-Za-z]/.test(name)) {
      return cleanMerchant(name);
    }
  }

  const pathMatch = UPI_FULL_PATH_PATTERN.exec(body);
  if (!pathMatch?.[1]) return null;

  const segments = pathMatch[1]
    .split("/")
    .map((s) => s.replace(/\*/g, "").trim())
    .filter((s) => s.length > 0);

  for (const seg of segments) {
    if (seg.includes("@")) return cleanVpaMerchant(seg);
  }

  for (let i = segments.length - 1; i >= 0; i--) {
    const seg = segments[i];
    const upper = seg.toUpperCase();
    if (UPI_TYPE_CODES.has(upper)) continue;
    if (UPI_PROVIDER_SUFFIXES.has(upper)) continue;
    if (/^\d{6,}$/.test(seg)) continue;
    if (/^[A-Z0-9]{2,4}$/.test(upper)) continue;
    if (/[A-Za-z]/.test(seg)) return cleanMerchant(seg);
  }

  for (const seg of segments) {
    const upper = seg.toUpperCase();
    if (UPI_TYPE_CODES.has(upper)) continue;
    if (UPI_PROVIDER_SUFFIXES.has(upper)) continue;
    if (/^\d{6,}$/.test(seg)) continue;
    if (/^[A-Z0-9]{2,4}$/.test(upper)) continue;
    if (/[A-Za-z]/.test(seg)) return cleanMerchant(seg);
  }

  return null;
}

function extractMerchant(body: string): string | null {
  const federalMatch = FEDERAL_SENT_UPI_PATTERN.exec(body);
  if (federalMatch?.[1]) return cleanVpaMerchant(federalMatch[1]);

  const atMatch = MERCHANT_AT_PATTERN.exec(body);
  if (atMatch?.[1]) return cleanMerchant(atMatch[1]);

  const colonMatch = MERCHANT_COLON_PATTERN.exec(body);
  if (colonMatch?.[1]) return cleanMerchant(colonMatch[1]);

  const upiMerchant = extractMerchantFromUpiPath(body);
  if (upiMerchant) return upiMerchant;

  const vpaMatch = UPI_TO_VPA_PATTERN.exec(body);
  if (vpaMatch?.[1]) return cleanVpaMerchant(vpaMatch[1]);

  const upiMatch = UPI_PATTERN.exec(body);
  if (upiMatch?.[1]) return cleanMerchant(upiMatch[1]);

  return null;
}

function extractUpiHint(body: string): string | null {
  if (!/\bUPI\b/i.test(body)) return null;

  const federalMatch = FEDERAL_SENT_UPI_PATTERN.exec(body);
  if (federalMatch?.[1]) return normalizeVpa(federalMatch[1]);

  const toVpaMatch = UPI_TO_VPA_PATTERN.exec(body);
  if (toVpaMatch?.[1]) return normalizeVpa(toVpaMatch[1]);

  const vpaMatch = /([\w.\-]+@[\w.\-]+)/i.exec(body);
  if (vpaMatch?.[1]) return normalizeVpa(vpaMatch[1]);

  const upiPath = /UPI\/[^/]+\/([\w.@]+)/i.exec(body);
  return upiPath?.[1] ?? null;
}

const MONTHS: Record<string, number> = {
  jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6,
  jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12,
};

function parseMonth(token: string): number {
  const lower = token.toLowerCase();
  if (MONTHS[lower] != null) return MONTHS[lower];
  return Number.parseInt(token, 10);
}

function extractTimestamp(body: string, fallback: Date): Date {
  const match = DATE_PATTERN.exec(body);
  if (!match?.[1]) return fallback;

  const parts = match[1].split(/[-/]/);
  if (parts.length !== 3) return fallback;

  try {
    const day = Number.parseInt(parts[0], 10);
    const month = parseMonth(parts[1]);
    let year = Number.parseInt(parts[2], 10);
    if (year < 100) year += 2000;

    let hour = fallback.getHours();
    let minute = fallback.getMinutes();
    let second = 0;
    const timeMatch = TIME_PATTERN.exec(body);
    if (timeMatch?.[1]) {
      const timeParts = timeMatch[1].split(":");
      hour = Number.parseInt(timeParts[0], 10);
      minute = Number.parseInt(timeParts[1], 10);
      if (timeParts.length > 2) {
        second = Number.parseInt(timeParts[2], 10);
      }
    }

    return new Date(year, month - 1, day, hour, minute, second);
  } catch {
    return fallback;
  }
}

function isAmbiguous(merchant: string | null, upiHint: string | null): boolean {
  if (!merchant || merchant.length === 0) return true;
  if (KNOWN_BRANDS.has(merchant)) return false;

  if (upiHint || merchant.includes(" ") || merchant.includes("@")) {
    const looksLikePerson = /^[A-Z]+(?: [A-Z]+)*$/.test(merchant);
    if (looksLikePerson && merchant.split(" ").length <= 4) return true;
    if (merchant.includes("@")) return true;
  }

  return false;
}

export function parseRawIngestRules(ingest: RawIngestInput): ParseResult {
  const body = ingest.body.trim();
  if (body.length === 0) {
    return {
      classification: "unknown",
      confidence: 0,
      rulesVersion: RULES_VERSION,
    };
  }

  if (matchesAny(body, HARD_PROMO_PATTERNS)) {
    return {
      classification: "promo",
      confidence: 0.9,
      rulesVersion: RULES_VERSION,
    };
  }

  if (matchesAny(body, PROMO_PATTERNS) && !hasStrongTransactionSignal(body)) {
    return {
      classification: "promo",
      confidence: 0.85,
      rulesVersion: RULES_VERSION,
    };
  }

  if (matchesAny(body, REMINDER_PATTERNS) && !hasStrongTransactionSignal(body)) {
    return {
      classification: "billingReminder",
      confidence: 0.9,
      rulesVersion: RULES_VERSION,
    };
  }

  if (!hasStrongTransactionSignal(body)) {
    return {
      classification: "unknown",
      confidence: 0.2,
      rulesVersion: RULES_VERSION,
    };
  }

  const amount = extractAmount(body);
  if (amount == null) {
    return {
      classification: "unknown",
      confidence: 0.3,
      rulesVersion: RULES_VERSION,
    };
  }

  if (!INSTRUMENT_CONTEXT_PATTERN.test(body)) {
    return {
      classification: "unknown",
      confidence: 0.35,
      rulesVersion: RULES_VERSION,
    };
  }

  const type = extractType(body);
  const merchant = extractMerchant(body) ?? undefined;
  const last4 = extractInstrumentLast4(body) ?? undefined;
  const upiHint = extractUpiHint(body) ?? undefined;
  const timestamp = extractTimestamp(body, ingest.receivedAt);
  const ambiguous = isAmbiguous(merchant ?? null, upiHint ?? null);

  const candidate: ParsedTransactionCandidate = {
    amount,
    currency: "INR",
    type,
    merchant,
    timestamp,
    instrumentLast4: last4,
    upiHint,
    ambiguous,
  };

  return {
    classification: "transaction",
    candidate,
    confidence: ambiguous ? 0.65 : 0.92,
    rulesVersion: RULES_VERSION,
  };
}

export {RULES_VERSION};
