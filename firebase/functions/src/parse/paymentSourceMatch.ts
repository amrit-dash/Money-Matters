import {PaymentSourceRecord} from "./types";

export function normalizeLast4(value: string | null | undefined): string {
  if (!value || value.length === 0) return "";
  const digits = value.replace(/\D/g, "");
  if (digits.length === 0) return "";
  if (digits.length <= 4) return digits.padStart(4, "0");
  return digits.slice(-4);
}

function matchesMerchant(source: PaymentSourceRecord, merchant: string): boolean {
  if (source.merchantHints.length === 0) return false;
  const upper = merchant.toUpperCase();
  return source.merchantHints.some(
    (hint) => hint.length > 0 && upper.includes(hint.toUpperCase()),
  );
}

function matchesBodyPattern(source: PaymentSourceRecord, body: string): boolean {
  if (source.bodyPatterns.length === 0) return false;
  const normalized = body.toLowerCase();
  return source.bodyPatterns.some(
    (pattern) => pattern.length > 0 && normalized.includes(pattern.toLowerCase()),
  );
}

function matchesInstrumentHint(
  source: PaymentSourceRecord,
  hint: string,
): boolean {
  if (!source.last4) return false;
  return normalizeLast4(source.last4) === normalizeLast4(hint);
}

function matchesSender(source: PaymentSourceRecord, sender: string): boolean {
  if (source.senderHints.length === 0) return false;
  const normalized = sender.trim().toLowerCase();
  return source.senderHints.some(
    (hint) => normalized.includes(hint.trim().toLowerCase()),
  );
}

function matchesBody(source: PaymentSourceRecord, body: string): boolean {
  const normalizedName = source.name.trim().toLowerCase();
  if (normalizedName.length > 0 && body.toLowerCase().includes(normalizedName)) {
    return true;
  }
  return matchesBodyPattern(source, body);
}

/** Rules-first payment source resolution (mirrors Dart [matchPaymentSourceFromIngest]). */
export function matchPaymentSourceFromIngest(params: {
  sender: string;
  body: string;
  instrumentLast4?: string;
  merchant?: string;
  sources: PaymentSourceRecord[];
}): string | null {
  const {sender, body, instrumentLast4, merchant, sources} = params;
  if (sources.length === 0) return null;

  if (merchant && merchant.length > 0) {
    for (const source of sources) {
      if (matchesMerchant(source, merchant)) return source.id;
    }
  }

  for (const source of sources) {
    if (matchesBodyPattern(source, body)) return source.id;
  }

  if (instrumentLast4) {
    for (const source of sources) {
      if (matchesInstrumentHint(source, instrumentLast4)) return source.id;
    }
  }

  for (const source of sources) {
    if (matchesSender(source, sender)) return source.id;
  }

  for (const source of sources) {
    if (matchesBody(source, body)) return source.id;
  }

  return null;
}

export function matchCategory(
  merchant: string | undefined,
  categories: {id: string; merchantRules: string[]}[],
): string | null {
  if (!merchant || merchant.length === 0) return null;
  const upper = merchant.toUpperCase();
  for (const category of categories) {
    for (const rule of category.merchantRules) {
      if (upper.includes(rule.toUpperCase())) return category.id;
    }
  }
  return null;
}
