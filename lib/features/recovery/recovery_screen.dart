import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import 'recovery_repository.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.repository});

  final RecoveryRepository repository;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _pasteController = TextEditingController();
  IngestStatus? _status;
  bool _loading = true;
  bool _submitting = false;
  String? _lastSubmitMessage;
  String? _error;

  final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.repository.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      await widget.repository.triggerSync();
      await _refresh();
      if (!mounted) return;
      final message =
          widget.repository.lastSyncResult?.formatSyncMessage() ??
              'Queue drained and parsed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    }
  }

  Future<void> _submitPaste() async {
    final blocks = splitPastedMessages(_pasteController.text);
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste at least one SMS block')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ingests = await widget.repository.submitPastedMessages(blocks);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _lastSubmitMessage = 'Queued ${ingests.length} message(s) for parsing';
        _pasteController.clear();
      });
      _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Never';
    return _dateFormat.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
          ),
        ],
      ),
      body: _loading && _status == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Ingest status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _StatusCard(
                    label: 'Last sync',
                    value: _formatTime(_status?.lastSyncAt),
                  ),
                  _StatusCard(
                    label: 'Last ingest',
                    value: _formatTime(_status?.lastIngestAt),
                  ),
                  _StatusCard(
                    label: 'Pending in queue',
                    value: '${_status?.pendingCount ?? 0}',
                    highlight: (_status?.pendingCount ?? 0) > 0,
                  ),
                  if ((_status?.failedParseCount ?? 0) > 0)
                    _StatusCard(
                      label: 'Failed parses (last sync)',
                      value: '${_status!.failedParseCount}',
                      highlight: true,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _syncNow,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Drain queue now'),
                  ),
                  const Divider(height: 32),
                  Text(
                    'Multi-paste recovery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Copy SMS from Messages search and paste below. Separate messages with a blank line.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pasteController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText:
                          'Rs.500 debited from A/c **1234...\n\nRs.899 spent on card **4567...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _submitting ? null : _submitPaste,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit pasted SMS'),
                  ),
                  if (_lastSubmitMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastSubmitMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.connectSms),
                    child: const Text('Connect SMS setup'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
