import '../models/category.dart';
import '../models/payment_source.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import 'llm_parser.dart';
import 'parse_result.dart';
import 'rules_parser.dart';

/// Orchestrates rules-first parsing with an optional LLM refinement gate.
class ParseService {
  ParseService({
    RulesParser? rulesParser,
    LlmParser? llmParser,
  })  : _rulesParser = rulesParser ?? const RulesParser(),
        _llmParser = llmParser ?? const NoOpLlmParser();

  final RulesParser _rulesParser;
  final LlmParser _llmParser;

  Future<ParseServiceOutcome> parse(
    RawIngest ingest, {
    List<PaymentSource> paymentSources = const [],
    List<Category> categories = const [],
  }) async {
    var result = _rulesParser.parse(ingest);

    final llmRefined = await _llmParser.refine(ingest, result);
    if (llmRefined != null) {
      result = llmRefined;
    }

    if (!result.isTransaction || result.candidate == null) {
      return ParseServiceOutcome(result: result);
    }

    final candidate = result.candidate!;
    final paymentSourceId = _matchPaymentSource(
      ingest,
      candidate,
      paymentSources,
    );
    final categoryId = _matchCategory(candidate, categories);

    final transaction = Transaction(
      rawIngestId: ingest.id,
      amount: candidate.amount,
      currency: candidate.currency,
      merchant: candidate.merchant,
      timestamp: candidate.timestamp,
      categoryId: categoryId,
      paymentSourceId: paymentSourceId,
      unmatched: paymentSourceId == null,
      ambiguous: candidate.ambiguous || categoryId == null,
      type: candidate.type,
    );

    return ParseServiceOutcome(result: result, transaction: transaction);
  }

  String? _matchPaymentSource(
    RawIngest ingest,
    ParsedTransactionCandidate candidate,
    List<PaymentSource> sources,
  ) {
    if (sources.isEmpty) return null;

    if (candidate.instrumentLast4 != null) {
      for (final source in sources) {
        if (source.matchesInstrumentHint(candidate.instrumentLast4)) {
          return source.id;
        }
      }
    }

    for (final source in sources) {
      if (source.matchesSender(ingest.sender)) {
        return source.id;
      }
    }

    for (final source in sources) {
      if (source.matchesBody(ingest.body)) {
        return source.id;
      }
    }

    return null;
  }

  String? _matchCategory(
    ParsedTransactionCandidate candidate,
    List<Category> categories,
  ) {
    if (candidate.merchant == null) return null;
    for (final category in categories) {
      final match = category.matchMerchant(candidate.merchant);
      if (match != null) return match;
    }
    return null;
  }
}
