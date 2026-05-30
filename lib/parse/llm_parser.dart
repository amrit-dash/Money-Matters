import '../models/raw_ingest.dart';
import 'parse_result.dart';

/// Optional LLM gate for ambiguous parses. Default implementation is a no-op.
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
