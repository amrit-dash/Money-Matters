/// LLM backends supported by Agent settings and Cloud Functions.
enum LlmProvider {
  gemini,
  openrouter,
  grok,
  mistral,
  other;

  String get id => name;

  String get label {
    switch (this) {
      case LlmProvider.gemini:
        return 'Gemini';
      case LlmProvider.openrouter:
        return 'Open Router';
      case LlmProvider.grok:
        return 'Grok';
      case LlmProvider.mistral:
        return 'Mistral';
      case LlmProvider.other:
        return 'Other';
    }
  }

  static LlmProvider fromId(String? raw) {
    final value = raw?.trim().toLowerCase();
    return LlmProvider.values.firstWhere(
      (p) => p.id == value,
      orElse: () => LlmProvider.gemini,
    );
  }
}
