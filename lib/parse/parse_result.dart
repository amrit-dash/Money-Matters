import '../models/transaction.dart';

enum IngestClassification {
  transaction,
  billingReminder,
  promo,
  unknown,
}

class ParsedTransactionCandidate {
  const ParsedTransactionCandidate({
    required this.amount,
    this.currency = 'INR',
    required this.type,
    this.merchant,
    required this.timestamp,
    this.instrumentLast4,
    this.upiHint,
    this.ambiguous = false,
  });

  final double amount;
  final String currency;
  final TransactionType type;
  final String? merchant;
  final DateTime timestamp;
  final String? instrumentLast4;
  final String? upiHint;
  final bool ambiguous;
}

class ParseResult {
  const ParseResult({
    required this.classification,
    this.candidate,
    required this.confidence,
    required this.rulesVersion,
  });

  final IngestClassification classification;
  final ParsedTransactionCandidate? candidate;
  final double confidence;
  final String rulesVersion;

  bool get isTransaction => classification == IngestClassification.transaction;
}

class ParseServiceOutcome {
  const ParseServiceOutcome({
    required this.result,
    this.transaction,
  });

  final ParseResult result;
  final Transaction? transaction;
}
