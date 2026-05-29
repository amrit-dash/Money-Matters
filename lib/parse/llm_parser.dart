import '../models/raw_ingest.dart';
import 'parse_result.dart';

/// Optional LLM gate for ambiguous parses (v1.1). MVP ships a no-op fallback.
abstract class LlmParser {
  Future<ParseResult?> refine(RawIngest ingest, ParseResult rulesResult);
}

/// Returns null so [ParseService] keeps the rules result unchanged.
class NoOpLlmParser implements LlmParser {
  const NoOpLlmParser();

  @override
  Future<ParseResult?> refine(RawIngest ingest, ParseResult rulesResult) async {
    return null;
  }
}
