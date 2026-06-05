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

  test('fromFirestore reads per-provider models and fetchedModels', () {
    final settings = LlmSettings.fromFirestore({
      'provider': 'gemini',
      'models': {
        'gemini': 'gemini-2.5-flash',
        'grok': 'grok-4.3',
      },
      'fetchedModels': {
        'gemini': ['gemini-2.0-flash', 'gemini-2.5-flash'],
        'grok': ['grok-4.3', 'grok-build-0.1'],
      },
    });

    expect(settings.modelFor(LlmProvider.gemini), 'gemini-2.5-flash');
    expect(settings.modelFor(LlmProvider.grok), 'grok-4.3');
    expect(settings.fetchedModelsFor(LlmProvider.gemini), [
      'gemini-2.0-flash',
      'gemini-2.5-flash',
    ]);
    expect(settings.fetchedModelsFor(LlmProvider.grok), [
      'grok-4.3',
      'grok-build-0.1',
    ]);
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

  test('withProviderModel keeps other provider models', () {
    const settings = LlmSettings(
      provider: LlmProvider.gemini,
      models: {
        LlmProvider.gemini: 'gemini-2.0-flash',
        LlmProvider.grok: 'grok-4.3',
      },
    );

    final updated = settings
        .withProviderModel(LlmProvider.gemini, 'gemini-2.5-flash')
        .copyWith(provider: LlmProvider.grok);

    expect(updated.modelFor(LlmProvider.gemini), 'gemini-2.5-flash');
    expect(updated.effectiveModel, 'grok-4.3');
  });

  test('toFirestore writes apiKeys, models, fetchedModels, and active apiKey', () {
    const settings = LlmSettings(
      enabled: true,
      provider: LlmProvider.grok,
      apiKeys: {
        LlmProvider.gemini: 'gem',
        LlmProvider.grok: 'xai',
      },
      models: {
        LlmProvider.gemini: 'gemini-2.0-flash',
        LlmProvider.grok: 'grok-4.3',
      },
      fetchedModels: {
        LlmProvider.grok: ['grok-4.3', 'grok-build-0.1'],
      },
    );

    final payload = settings.toFirestore();
    expect(payload['apiKeys'], {
      'gemini': 'gem',
      'grok': 'xai',
    });
    expect(payload['models'], {
      'gemini': 'gemini-2.0-flash',
      'grok': 'grok-4.3',
    });
    expect(payload['fetchedModels'], {
      'grok': ['grok-4.3', 'grok-build-0.1'],
    });
    expect(payload['apiKey'], 'xai');
    expect(payload['provider'], 'grok');
    expect(payload['model'], 'grok-4.3');
  });

  test('toFirestore always includes active provider model in models map', () {
    const settings = LlmSettings(
      enabled: true,
      provider: LlmProvider.grok,
      apiKeys: {LlmProvider.grok: 'xai'},
    );

    final persisted = settings.withProviderModel(
      LlmProvider.grok,
      settings.effectiveModel,
    );
    final payload = persisted.toFirestore();

    expect(payload['models'], {'grok': 'grok-4.3'});
    expect(payload['model'], 'grok-4.3');
  });

  test('fromFirestore parses groq provider and default model', () {
    final settings = LlmSettings.fromFirestore({
      'provider': 'groq',
      'apiKeys': {'groq': 'gsk-test'},
    });

    expect(settings.provider, LlmProvider.groq);
    expect(settings.apiKeyFor(LlmProvider.groq), 'gsk-test');
    expect(settings.effectiveModel, 'llama-3.3-70b-versatile');
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
