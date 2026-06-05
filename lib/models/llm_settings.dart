import 'package:cloud_firestore/cloud_firestore.dart';

import 'llm_provider.dart';

/// Per-user LLM configuration stored at `users/{uid}/settings/llm`.
class LlmSettings {
  const LlmSettings({
    this.enabled = false,
    this.provider = LlmProvider.gemini,
    Map<LlmProvider, String>? apiKeys,
    Map<LlmProvider, String>? models,
    Map<LlmProvider, List<String>>? fetchedModels,
    this.model,
    this.baseUrl,
    this.updatedAt,
  })  : apiKeys = apiKeys ?? const {},
        models = models ?? const {},
        fetchedModels = fetchedModels ?? const {};

  final bool enabled;
  final LlmProvider provider;
  final Map<LlmProvider, String> apiKeys;
  final Map<LlmProvider, String> models;
  final Map<LlmProvider, List<String>> fetchedModels;
  final String? model;
  final String? baseUrl;
  final DateTime? updatedAt;

  static const defaultModels = {
    LlmProvider.gemini: 'gemini-2.0-flash',
    LlmProvider.openrouter: 'google/gemini-2.0-flash-001',
    LlmProvider.grok: 'grok-4.3',
    LlmProvider.groq: 'llama-3.3-70b-versatile',
    LlmProvider.mistral: 'mistral-small-latest',
    LlmProvider.other: 'gpt-4o-mini',
  };

  /// API key for the active [provider].
  String? get apiKey => apiKeyFor(provider);

  String? apiKeyFor(LlmProvider p) {
    final value = apiKeys[p];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? modelFor(LlmProvider p) {
    final fromMap = models[p];
    if (fromMap != null && fromMap.trim().isNotEmpty) {
      return fromMap.trim();
    }
    if (p == provider) {
      return _trimOrNull(model);
    }
    return null;
  }

  List<String> fetchedModelsFor(LlmProvider p) =>
      List.unmodifiable(fetchedModels[p] ?? const []);

  String get effectiveModel =>
      modelFor(provider) ?? defaultModels[provider]!;

  bool get isConfigured =>
      apiKey != null && effectiveModel.isNotEmpty;

  bool get needsBaseUrl => provider == LlmProvider.other;

  LlmSettings withProviderApiKey(LlmProvider p, String? key) {
    final next = Map<LlmProvider, String>.from(apiKeys);
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      next.remove(p);
    } else {
      next[p] = trimmed;
    }
    return copyWith(apiKeys: next);
  }

  LlmSettings withProviderModel(LlmProvider p, String? modelId) {
    final next = Map<LlmProvider, String>.from(models);
    final trimmed = modelId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      next.remove(p);
    } else {
      next[p] = trimmed;
    }
    return copyWith(
      models: next,
      model: p == provider ? trimmed : model,
    );
  }

  LlmSettings withProviderFetchedModels(
    LlmProvider p,
    List<String> list,
  ) {
    final next = Map<LlmProvider, List<String>>.from(fetchedModels);
    if (list.isEmpty) {
      next.remove(p);
    } else {
      next[p] = List<String>.from(list);
    }
    return copyWith(fetchedModels: next);
  }

  LlmSettings copyWith({
    bool? enabled,
    LlmProvider? provider,
    Map<LlmProvider, String>? apiKeys,
    Map<LlmProvider, String>? models,
    Map<LlmProvider, List<String>>? fetchedModels,
    String? apiKey,
    String? model,
    String? baseUrl,
    DateTime? updatedAt,
    bool clearApiKey = false,
    bool clearBaseUrl = false,
  }) {
    final activeProvider = provider ?? this.provider;
    var nextKeys = apiKeys ?? Map<LlmProvider, String>.from(this.apiKeys);
    if (clearApiKey) {
      nextKeys = Map<LlmProvider, String>.from(nextKeys)
        ..remove(activeProvider);
    } else if (apiKey != null) {
      nextKeys = Map<LlmProvider, String>.from(nextKeys);
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        nextKeys.remove(activeProvider);
      } else {
        nextKeys[activeProvider] = trimmed;
      }
    }
    return LlmSettings(
      enabled: enabled ?? this.enabled,
      provider: activeProvider,
      apiKeys: nextKeys,
      models: models ?? Map<LlmProvider, String>.from(this.models),
      fetchedModels: fetchedModels ??
          Map<LlmProvider, List<String>>.from(this.fetchedModels),
      model: model ?? this.model,
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LlmSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const LlmSettings();
    final updated = data['updatedAt'];
    final provider = LlmProvider.fromId(data['provider'] as String?);
    var keys = _parseApiKeys(data['apiKeys']);
    final legacy = _trimOrNull(data['apiKey']);
    if (legacy != null && keys[provider] == null) {
      keys = Map<LlmProvider, String>.from(keys)..[provider] = legacy;
    }
    var modelsMap = _parseModelsMap(data['models']);
    final legacyModel = _trimOrNull(data['model']);
    if (legacyModel != null && modelsMap[provider] == null) {
      modelsMap = Map<LlmProvider, String>.from(modelsMap)
        ..[provider] = legacyModel;
    }
    final fetchedMap = _parseFetchedModelsMap(data['fetchedModels']);
    return LlmSettings(
      enabled: data['enabled'] == true,
      provider: provider,
      apiKeys: keys,
      models: modelsMap,
      fetchedModels: fetchedMap,
      model: legacyModel,
      baseUrl: _trimOrNull(data['baseUrl']),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final keysPayload = <String, String>{
      for (final entry in apiKeys.entries)
        if (entry.value.trim().isNotEmpty) entry.key.id: entry.value.trim(),
    };
    final modelsPayload = <String, String>{
      for (final entry in models.entries)
        if (entry.value.trim().isNotEmpty) entry.key.id: entry.value.trim(),
    };
    final fetchedPayload = <String, List<String>>{
      for (final entry in fetchedModels.entries)
        if (entry.value.isNotEmpty) entry.key.id: List<String>.from(entry.value),
    };
    return {
      'enabled': enabled,
      'provider': provider.id,
      if (keysPayload.isNotEmpty) 'apiKeys': keysPayload,
      if (modelsPayload.isNotEmpty) 'models': modelsPayload,
      if (fetchedPayload.isNotEmpty) 'fetchedModels': fetchedPayload,
      if (apiKey != null) 'apiKey': apiKey,
      'model': effectiveModel,
      if (baseUrl != null && baseUrl!.isNotEmpty) 'baseUrl': baseUrl!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCallablePayload({bool includeSecrets = true}) {
    return {
      'provider': provider.id,
      if (includeSecrets && apiKey != null && apiKey!.isNotEmpty)
        'apiKey': apiKey!.trim(),
      'model': effectiveModel,
      if (baseUrl != null && baseUrl!.isNotEmpty) 'baseUrl': baseUrl!.trim(),
    };
  }

  static Map<LlmProvider, String> _parseApiKeys(dynamic raw) {
    if (raw is! Map) return {};
    final out = <LlmProvider, String>{};
    for (final entry in raw.entries) {
      final provider = LlmProvider.fromId(entry.key?.toString());
      final key = _trimOrNull(entry.value);
      if (key != null) out[provider] = key;
    }
    return out;
  }

  static Map<LlmProvider, String> _parseModelsMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <LlmProvider, String>{};
    for (final entry in raw.entries) {
      final provider = LlmProvider.fromId(entry.key?.toString());
      final modelId = _trimOrNull(entry.value);
      if (modelId != null) out[provider] = modelId;
    }
    return out;
  }

  static Map<LlmProvider, List<String>> _parseFetchedModelsMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <LlmProvider, List<String>>{};
    for (final entry in raw.entries) {
      final provider = LlmProvider.fromId(entry.key?.toString());
      final list = entry.value;
      if (list is! List) continue;
      final models = list
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (models.isNotEmpty) out[provider] = models;
    }
    return out;
  }

  static String? _trimOrNull(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
