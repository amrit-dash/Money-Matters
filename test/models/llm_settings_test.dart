import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/models/llm_provider.dart';
import 'package:money_matters/models/llm_settings.dart';

void main() {
  test('LlmSettings.fromFirestore parses enabled provider and key', () {
    final settings = LlmSettings.fromFirestore({
      'enabled': true,
      'provider': 'openrouter',
      'apiKey': 'sk-test',
      'model': 'anthropic/claude-3-haiku',
    });

    expect(settings.enabled, isTrue);
    expect(settings.provider, LlmProvider.openrouter);
    expect(settings.apiKey, 'sk-test');
    expect(settings.effectiveModel, 'anthropic/claude-3-haiku');
    expect(settings.isConfigured, isTrue);
  });

  test('toCallablePayload omits empty api key when includeSecrets false', () {
    const settings = LlmSettings(
      enabled: true,
      provider: LlmProvider.gemini,
      apiKey: 'key',
      model: 'gemini-2.0-flash',
    );
    final payload = settings.toCallablePayload(includeSecrets: false);
    expect(payload.containsKey('apiKey'), isFalse);
    expect(payload['provider'], 'gemini');
  });
}
