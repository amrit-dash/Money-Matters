import {createHash} from "crypto";

/**
 * Normalize sender for idempotency: trim + lowercase.
 */
export function normalizeSender(sender: string): string {
  return sender.trim().toLowerCase();
}

/**
 * Collapse internal whitespace in SMS body to a single space.
 */
export function normalizeBody(body: string): string {
  return body.trim().replace(/\s+/g, " ");
}

/**
 * Floor an ISO8601 timestamp to the start of its minute (UTC).
 * Returns ISO8601 string used in the idempotency key.
 */
export function floorToMinute(receivedAt: string): string {
  const date = new Date(receivedAt);
  if (Number.isNaN(date.getTime())) {
    throw new Error("Invalid receivedAt: must be ISO8601");
  }
  date.setUTCSeconds(0, 0);
  return date.toISOString();
}

/**
 * idempotencyKey = sha256(senderNorm + "|" + bodyNorm + "|" + minuteBucket)
 */
export function computeIdempotencyKey(
  sender: string,
  body: string,
  receivedAt: string,
): string {
  const senderNorm = normalizeSender(sender);
  const bodyNorm = normalizeBody(body);
  const minuteBucket = floorToMinute(receivedAt);
  const payload = `${senderNorm}|${bodyNorm}|${minuteBucket}`;
  return createHash("sha256").update(payload, "utf8").digest("hex");
}

/**
 * Hash a bearer token for comparison against device_tokens.tokenHash.
 */
export function hashToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}
