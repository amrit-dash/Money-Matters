import 'package:cloud_firestore/cloud_firestore.dart';

import 'llm_provider.dart';

/// Per-user LLM configuration stored at `users/{uid}/settings/llm`.
class LlmSettings {
  const LlmSettings({
    this.enabled = false,
    this.provider = LlmProvider.gemini,
    this.apiKey,
    this.model,
    this.baseUrl,
    this.updatedAt,
  });

  final bool enabled;
  final LlmProvider provider;
  final String? apiKey;
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

  String get effectiveModel =>
      (model != null && model!.isNotEmpty) ? model! : defaultModels[provider]!;

  bool get isConfigured =>
      apiKey != null && apiKey!.trim().isNotEmpty && effectiveModel.isNotEmpty;

  bool get needsBaseUrl => provider == LlmProvider.other;

  LlmSettings copyWith({
    bool? enabled,
    LlmProvider? provider,
    String? apiKey,
    String? model,
    String? baseUrl,
    DateTime? updatedAt,
    bool clearApiKey = false,
    bool clearBaseUrl = false,
  }) {
    return LlmSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      model: model ?? this.model,
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LlmSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const LlmSettings();
    final updated = data['updatedAt'];
    return LlmSettings(
      enabled: data['enabled'] == true,
      provider: LlmProvider.fromId(data['provider'] as String?),
      apiKey: _trimOrNull(data['apiKey']),
      model: _trimOrNull(data['model']),
      baseUrl: _trimOrNull(data['baseUrl']),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabled': enabled,
      'provider': provider.id,
      if (apiKey != null && apiKey!.isNotEmpty) 'apiKey': apiKey!.trim(),
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

  static String? _trimOrNull(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
