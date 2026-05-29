import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'onboarding_state.dart';

class ShortcutsSetupScreen extends StatefulWidget {
  const ShortcutsSetupScreen({
    super.key,
    required this.state,
    required this.onComplete,
    this.showFinishOnboarding = true,
  });

  final OnboardingState state;
  final VoidCallback onComplete;
  final bool showFinishOnboarding;

  @override
  State<ShortcutsSetupScreen> createState() => _ShortcutsSetupScreenState();
}

class _ShortcutsSetupScreenState extends State<ShortcutsSetupScreen> {
  final _urlController = TextEditingController();
  bool _testPosting = false;
  String? _testResult;

  static const _checklistItems = [
    'Message automation: Run Immediately + keyword (e.g. debited)',
    'Use Shortcut Input (triggering SMS) for body and sender — see setup guide',
    'POST via Get Contents of URL (inline automation or library shortcut)',
    'If Run Shortcut: set Input to Shortcut Input so the SMS is passed through',
    'Optional: Shortcut B — Sync now (moneymatters://recovery)',
  ];

  final Set<int> _checkedSteps = {};

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.state.ingestUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _copyField(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _runTestPost() async {
    setState(() {
      _testPosting = true;
      _testResult = null;
    });

    final url = _urlController.text.trim();
    widget.state.setIngestUrl(url);

    try {
      final body = jsonEncode({
        'body':
            'Rs.1.00 debited from A/c **0000 at HEALTH CHECK on ${DateTime.now().toIso8601String()}',
        'sender': 'MM-HEALTH',
        'receivedAt': DateTime.now().toIso8601String(),
        'deviceId': widget.state.deviceId,
        'source': 'shortcuts-automation-v1',
        'batchHint': null,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.state.ingestToken}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;
      setState(() {
        _testResult = 'HTTP ${response.statusCode}: ${response.body}';
        if (response.statusCode == 200 || response.statusCode == 201) {
          widget.state.confirmHealthCheckManual();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = 'Failed: $e\nConfigure Firebase URL or use manual confirm.';
      });
    } finally {
      if (mounted) setState(() => _testPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect SMS')),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Shortcuts automations POST each financial SMS while the app is closed.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (widget.state.deviceTokenSynced)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Device token synced to Firebase'),
                    subtitle: Text(
                      'Bearer token registered — safe to copy into Shortcuts.',
                    ),
                  ),
                )
              else if (widget.state.deviceTokenSyncError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Token sync failed'),
                    subtitle: Text(widget.state.deviceTokenSyncError!),
                  ),
                ),
              const SizedBox(height: 16),
              _CopyableField(
                label: 'Ingest URL',
                value: _urlController.text.trim(),
                onCopy: () => _copyField('Ingest URL', _urlController.text.trim()),
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Ingest URL',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: widget.state.setIngestUrl,
                ),
              ),
              const SizedBox(height: 12),
              _CopyableField(
                label: 'Bearer token',
                value: widget.state.ingestToken,
                onCopy: () => _copyField('Bearer token', widget.state.ingestToken),
              ),
              const SizedBox(height: 12),
              _CopyableField(
                label: 'Device ID',
                value: widget.state.deviceId,
                onCopy: () => _copyField('Device ID', widget.state.deviceId),
              ),
              const Divider(height: 32),
              Text('Setup checklist', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...List.generate(_checklistItems.length, (i) {
                return CheckboxListTile(
                  value: _checkedSteps.contains(i),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _checkedSteps.add(i);
                      } else {
                        _checkedSteps.remove(i);
                      }
                      widget.state.markChecklistComplete(
                        _checkedSteps.length == _checklistItems.length,
                      );
                    });
                  },
                  title: Text(_checklistItems[i]),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              }),
              const Divider(height: 32),
              Text('Health check', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Send a test POST or confirm you received a test SMS in the queue.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testPosting ? null : _runTestPost,
                      child: _testPosting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test POST'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.state.confirmHealthCheckManual,
                      child: const Text('Manual confirm'),
                    ),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 8),
                Text(_testResult!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (widget.state.healthCheckPassed)
                const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Health check passed'),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.state.skipHealthCheck();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Skipped — automations may not be working. Re-check in Recovery.',
                      ),
                    ),
                  );
                },
                child: const Text('Skip with warning'),
              ),
              const SizedBox(height: 24),
              if (widget.showFinishOnboarding)
                FilledButton(
                  onPressed: widget.state.shortcutsGateSatisfied &&
                          widget.state.shortcutsChecklistComplete
                      ? widget.onComplete
                      : null,
                  child: const Text('Finish onboarding'),
                )
              else
                FilledButton(
                  onPressed: widget.state.shortcutsGateSatisfied
                      ? widget.onComplete
                      : null,
                  child: const Text('Done'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CopyableField extends StatelessWidget {
  const _CopyableField({
    required this.label,
    required this.value,
    required this.onCopy,
    this.child,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (child != null)
          child!
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            label: Text('Copy $label'),
          ),
        ),
      ],
    );
  }
}
