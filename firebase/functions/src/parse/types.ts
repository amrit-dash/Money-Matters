export type IngestClassification =
  | "transaction"
  | "billingReminder"
  | "promo"
  | "unknown";

export type TransactionType = "debit" | "credit";

export interface RawIngestInput {
  id: string;
  body: string;
  sender: string;
  receivedAt: Date;
}

export interface ParsedTransactionCandidate {
  amount: number;
  currency: string;
  type: TransactionType;
  merchant?: string;
  timestamp: Date;
  instrumentLast4?: string;
  upiHint?: string;
  ambiguous: boolean;
}

export interface ParseResult {
  classification: IngestClassification;
  candidate?: ParsedTransactionCandidate;
  confidence: number;
  rulesVersion: string;
}

export interface PaymentSourceRecord {
  id: string;
  name: string;
  last4?: string;
  senderHints: string[];
  merchantHints: string[];
  bodyPatterns: string[];
}

export interface CategoryRecord {
  id: string;
  merchantRules: string[];
}

