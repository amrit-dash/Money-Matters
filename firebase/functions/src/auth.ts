import {getFirestore} from "firebase-admin/firestore";
import {hashToken} from "./normalize";

export interface AuthResult {
  uid: string;
  deviceId: string;
}

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthError";
  }
}

/**
 * Resolve uid from Bearer token + deviceId via users/{uid}/device_tokens/{deviceId}.tokenHash
 */
export async function resolveUidFromBearer(
  authorizationHeader: string | undefined,
  deviceId: string,
): Promise<AuthResult> {
  if (!authorizationHeader?.startsWith("Bearer ")) {
    throw new AuthError("Missing or invalid Authorization header");
  }

  const token = authorizationHeader.slice("Bearer ".length).trim();
  if (!token) {
    throw new AuthError("Empty bearer token");
  }

  if (!deviceId || typeof deviceId !== "string" || !deviceId.trim()) {
    throw new AuthError("deviceId is required for token validation");
  }

  const tokenHash = hashToken(token);
  const db = getFirestore();

  const snapshot = await db
    .collectionGroup("device_tokens")
    .where("tokenHash", "==", tokenHash)
    .limit(10)
    .get();

  const match = snapshot.docs.find((doc) => doc.id === deviceId.trim());
  if (!match) {
    throw new AuthError("Invalid device token");
  }

  const uid = match.ref.parent.parent?.id;
  if (!uid) {
    throw new AuthError("Invalid device token path");
  }

  return {uid, deviceId: deviceId.trim()};
}
