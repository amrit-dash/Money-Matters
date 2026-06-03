import 'package:cloud_firestore/cloud_firestore.dart';

import 'llm_provider.dart';

/// Per-user LLM configuration stored at `users/{uid}/settings/llm`.
class LlmSettings {
  const LlmSettings({
    this.enabled = false,
    this.provider = LlmProvider.gemini,
    Map<LlmProvider, String>? apiKeys,
    this.model,
    this.baseUrl,
    this.updatedAt,
  }) : apiKeys = apiKeys ?? const {};

  final bool enabled;
  final LlmProvider provider;
  final Map<LlmProvider, String> apiKeys;
  final String? model;
  final String? baseUrl;
  final DateTime? updatedAt;

  static const defaultModels = {
    LlmProvider.gemini: 'gemini-2.0-flash',
    LlmProvider.openrouter: 'google/gemini-2.0-flash-001',
    LlmProvider.grok: 'grok-2-latest',
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

  String get effectiveModel =>
      (model != null && model!.isNotEmpty) ? model! : defaultModels[provider]!;

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

  LlmSettings copyWith({
    bool? enabled,
    LlmProvider? provider,
    Map<LlmProvider, String>? apiKeys,
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
    return LlmSettings(
      enabled: data['enabled'] == true,
      provider: provider,
      apiKeys: keys,
      model: _trimOrNull(data['model']),
      baseUrl: _trimOrNull(data['baseUrl']),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final keysPayload = <String, String>{
      for (final entry in apiKeys.entries)
        if (entry.value.trim().isNotEmpty) entry.key.id: entry.value.trim(),
    };
    return {
      'enabled': enabled,
      'provider': provider.id,
      if (keysPayload.isNotEmpty) 'apiKeys': keysPayload,
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

  static String? _trimOrNull(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
