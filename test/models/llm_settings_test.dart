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
    expect(settings.apiKeyFor(LlmProvider.openrouter), 'sk-test');
    expect(settings.effectiveModel, 'anthropic/claude-3-haiku');
    expect(settings.isConfigured, isTrue);
  });

  test('fromFirestore migrates legacy apiKey into apiKeys for provider', () {
    final settings = LlmSettings.fromFirestore({
      'provider': 'grok',
      'apiKey': 'xai-legacy',
    });

    expect(settings.apiKeyFor(LlmProvider.grok), 'xai-legacy');
    expect(settings.apiKeyFor(LlmProvider.gemini), isNull);
  });

  test('fromFirestore reads per-provider apiKeys map', () {
    final settings = LlmSettings.fromFirestore({
      'provider': 'mistral',
      'apiKeys': {
        'gemini': 'gem-key',
        'mistral': 'mistral-key',
        'grok': 'grok-key',
      },
    });

    expect(settings.apiKey, 'mistral-key');
    expect(settings.apiKeyFor(LlmProvider.gemini), 'gem-key');
    expect(settings.apiKeyFor(LlmProvider.grok), 'grok-key');
  });

  test('withProviderApiKey keeps other providers keys', () {
    const settings = LlmSettings(
      provider: LlmProvider.gemini,
      apiKeys: {
        LlmProvider.gemini: 'gem-key',
        LlmProvider.mistral: 'mistral-key',
      },
    );

    final updated = settings
        .withProviderApiKey(LlmProvider.gemini, 'new-gem')
        .copyWith(provider: LlmProvider.mistral);

    expect(updated.apiKeyFor(LlmProvider.gemini), 'new-gem');
    expect(updated.apiKeyFor(LlmProvider.mistral), 'mistral-key');
    expect(updated.apiKey, 'mistral-key');
  });

  test('toFirestore writes apiKeys and active apiKey', () {
    const settings = LlmSettings(
      enabled: true,
      provider: LlmProvider.grok,
      apiKeys: {
        LlmProvider.gemini: 'gem',
        LlmProvider.grok: 'xai',
      },
      model: 'grok-2-latest',
    );

    final payload = settings.toFirestore();
    expect(payload['apiKeys'], {
      'gemini': 'gem',
      'grok': 'xai',
    });
    expect(payload['apiKey'], 'xai');
    expect(payload['provider'], 'grok');
  });

  test('toCallablePayload omits empty api key when includeSecrets false', () {
    const settings = LlmSettings(
      enabled: true,
      provider: LlmProvider.gemini,
      apiKeys: {LlmProvider.gemini: 'key'},
      model: 'gemini-2.0-flash',
    );
    final payload = settings.toCallablePayload(includeSecrets: false);
    expect(payload.containsKey('apiKey'), isFalse);
    expect(payload['provider'], 'gemini');
  });
}
