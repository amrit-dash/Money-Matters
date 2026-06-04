import 'package:flutter/material.dart';

import '../../core/widgets/app_ui.dart';
import '../../models/llm_provider.dart';
import '../../models/llm_settings.dart';
import '../../services/llm_settings_service.dart';

/// BYOK LLM provider, API key, and model selection for Cloud Functions.
class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({
    super.key,
    required this.llmSettingsService,
  });

  final LlmSettingsService llmSettingsService;

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _obscureKey = true;
  LlmSettings _draft = const LlmSettings();

  List<String> get _fetchedModels =>
      _draft.fetchedModelsFor(_draft.provider);

  String get _selectedModel => _draft.effectiveModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _syncFieldsFromDraft(LlmSettings settings) {
    _apiKeyController.text = settings.apiKeyFor(settings.provider) ?? '';
    _baseUrlController.text = settings.baseUrl ?? '';
    _modelController.text = settings.effectiveModel;
  }

  Future<void> _load() async {
    final settings = await widget.llmSettingsService.load(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _draft = settings;
      _syncFieldsFromDraft(settings);
      _loading = false;
    });
  }

  String? get _apiKeyFromField {
    final trimmed = _apiKeyController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  LlmSettings _persistFieldEdits(LlmSettings base) {
    final modelFromField = _modelController.text.trim();
    final modelToPersist = modelFromField.isNotEmpty
        ? modelFromField
        : (base.modelFor(base.provider) ?? base.effectiveModel);
    return base
        .withProviderApiKey(base.provider, _apiKeyFromField)
        .withProviderModel(base.provider, modelToPersist)
        .copyWith(
          baseUrl: _baseUrlController.text.trim().isEmpty
              ? null
              : _baseUrlController.text.trim(),
        );
  }

  LlmSettings get _workingDraft => _persistFieldEdits(_draft);

  void _setSelectedModel(String? modelId) {
    if (modelId == null || modelId.trim().isEmpty) return;
    setState(() {
      _draft = _draft.withProviderModel(_draft.provider, modelId.trim());
      _modelController.text = modelId.trim();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testApiKey() async {
    final draft = _workingDraft;
    if (draft.apiKey == null || draft.apiKey!.isEmpty) {
      _snack('Enter an API key first');
      return;
    }
    if (draft.needsBaseUrl && (draft.baseUrl == null || draft.baseUrl!.isEmpty)) {
      _snack('Enter a base URL for Other provider');
      return;
    }

    await _runBusy(() async {
      try {
        await widget.llmSettingsService.testApiKey(draft);
        if (!mounted) return;
        setState(() => _draft = draft);
        _snack('API key verified');
      } catch (e) {
        if (!mounted) return;
        _snack('Test failed: $e');
      }
    });
  }

  Future<void> _fetchModels() async {
    final draft = _workingDraft;
    if (draft.apiKey == null || draft.apiKey!.isEmpty) {
      _snack('Enter an API key first');
      return;
    }

    await _runBusy(() async {
      try {
        final models = await widget.llmSettingsService.fetchModels(draft);
        if (!mounted) return;
        var next = draft.withProviderFetchedModels(draft.provider, models);
        if (models.isNotEmpty) {
          final current = next.modelFor(next.provider);
          final selected = current != null && models.contains(current)
              ? current
              : models.first;
          next = next.withProviderModel(next.provider, selected);
        }
        setState(() {
          _draft = next;
          _modelController.text = next.effectiveModel;
        });
        _snack('Loaded ${models.length} model(s)');
      } catch (e) {
        if (!mounted) return;
        _snack('Fetch failed: $e');
      }
    });
  }

  Future<void> _save() async {
    var draft = _workingDraft.copyWith(enabled: _draft.enabled);
    // Always persist the active provider's model into the per-provider map.
    draft = draft.withProviderModel(draft.provider, draft.effectiveModel);

    if (draft.enabled && !draft.isConfigured) {
      _snack('Enable requires a provider, API key, and model');
      return;
    }
    if (draft.needsBaseUrl && (draft.baseUrl == null || draft.baseUrl!.isEmpty)) {
      _snack('Base URL required for Other provider');
      return;
    }

    await _runBusy(() async {
      try {
        await widget.llmSettingsService.save(draft);
        if (!mounted) return;
        setState(() => _draft = draft);
        _snack('Agent settings saved');
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        _snack('Could not save: $e');
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _switchProvider(LlmProvider nextProvider) {
    final updated = _workingDraft.copyWith(provider: nextProvider);
    setState(() {
      _draft = updated;
      _syncFieldsFromDraft(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent settings'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                SwitchListTile(
                  title: const Text('Enable LLM auto-classify'),
                  subtitle: const Text(
                    'When off, ambiguous transactions stay in Review without calling the cloud.',
                  ),
                  value: _draft.enabled,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _draft = _draft.copyWith(enabled: v)),
                ),
                const SizedBox(height: AppSpacing.section),
                const AppSectionHeader(
                  title: 'Provider',
                  subtitle: 'API key is stored in your Firestore user settings',
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<LlmProvider>(
                          key: ValueKey('provider-${_draft.provider.id}'),
                          initialValue: _draft.provider,
                          decoration: const InputDecoration(
                            labelText: 'Provider',
                          ),
                          items: [
                            for (final p in LlmProvider.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (p) {
                                  if (p == null) return;
                                  _switchProvider(p);
                                },
                        ),
                        const SizedBox(height: AppSpacing.item),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'API key',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_draft.needsBaseUrl) ...[
                          const SizedBox(height: AppSpacing.item),
                          TextField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Base URL (OpenAI-compatible)',
                              hintText: 'https://api.example.com',
                            ),
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.item),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _testApiKey,
                                child: const Text('Test API key'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _fetchModels,
                                child: const Text('Fetch models'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.item),
                        if (_fetchedModels.isEmpty)
                          TextField(
                            controller: _modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model ID',
                              hintText: 'e.g. gemini-2.0-flash',
                            ),
                            onChanged: (v) => _setSelectedModel(v),
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey('model-$_selectedModel'),
                            initialValue: _fetchedModels.contains(_selectedModel)
                                ? _selectedModel
                                : _fetchedModels.first,
                            decoration: const InputDecoration(
                              labelText: 'Model',
                            ),
                            items: [
                              for (final m in _fetchedModels)
                                DropdownMenuItem(value: m, child: Text(m)),
                            ],
                            onChanged: _busy ? null : _setSelectedModel,
                          ),
                        const SizedBox(height: AppSpacing.tight),
                        Text(
                          'Default for ${_draft.provider.label}: '
                          '${LlmSettings.defaultModels[_draft.provider]}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: AppSpacing.section),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}
