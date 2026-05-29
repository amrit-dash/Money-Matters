import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Normalizes sender for idempotency: trim + lowercase.
String normalizeSender(String sender) => sender.trim().toLowerCase();

/// Collapses internal whitespace in SMS body for idempotency.
String normalizeBody(String body) {
  return body.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Floors [receivedAt] to the start of its minute (UTC).
DateTime floorToMinute(DateTime receivedAt) {
  return DateTime.utc(
    receivedAt.year,
    receivedAt.month,
    receivedAt.day,
    receivedAt.hour,
    receivedAt.minute,
  );
}

/// Client-side preview of the server idempotency key (sha256 hex).
///
/// Matches Cloud Function contract: sha256(senderNorm|bodyNorm|minuteBucket).
String computeIdempotencyKey({
  required String sender,
  required String body,
  required DateTime receivedAt,
}) {
  final senderNorm = normalizeSender(sender);
  final bodyNorm = normalizeBody(body);
  final minuteBucket = floorToMinute(receivedAt.toUtc()).toIso8601String();
  final payload = '$senderNorm|$bodyNorm|$minuteBucket';
  return sha256.convert(utf8.encode(payload)).toString();
}
