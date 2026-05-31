import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
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

  AppStatTone _pendingTone(IngestStatus status) {
    if (status.totalPending > 0) return AppStatTone.warning;
    return AppStatTone.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Dashboard',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
          ),
        ],
      ),
      body: _loading && _status == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppSectionHeader(
                    title: 'Queue status',
                    subtitle:
                        'On this phone vs still waiting in Firebase cloud',
                  ),
                  if (_status != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppStatTile(
                            label: 'Synced SMS',
                            value: '${_status!.syncedMessageCount}',
                            icon: Icons.cloud_done_outlined,
                            tone: AppStatTone.neutral,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.item),
                        Expanded(
                          child: AppStatTile(
                            label: 'Pending parse',
                            value: '${_status!.totalPending}',
                            icon: Icons.hourglass_top_outlined,
                            tone: _pendingTone(_status!),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.item),
                        Expanded(
                          child: AppStatTile(
                            label: 'Parsed txns',
                            value: '${_status!.parsedTransactionCount}',
                            icon: Icons.receipt_long_outlined,
                            tone: AppStatTone.success,
                          ),
                        ),
                      ],
                    ),
                    if (_status!.pendingMessageCount > 0 ||
                        _status!.pendingParseJobCount > 0 ||
                        _status!.cloudPendingParseJobCount > 0) ...[
                      const SizedBox(height: AppSpacing.item),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending breakdown',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.tight),
                              Text(
                                'On this phone',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              if (_status!.pendingMessageCount > 0)
                                _BreakdownRow(
                                  label: 'SMS waiting to parse',
                                  count: _status!.pendingMessageCount,
                                ),
                              if (_status!.pendingParseJobCount > 0)
                                _BreakdownRow(
                                  label: 'Parse jobs (local mirror)',
                                  count: _status!.pendingParseJobCount,
                                ),
                              if (_status!.pendingMessageCount == 0 &&
                                  _status!.pendingParseJobCount == 0)
                                Text(
                                  'Nothing queued locally',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: AppSpacing.tight),
                              Text(
                                'In Firebase cloud',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              if (_status!.cloudPendingParseJobCount > 0)
                                _BreakdownRow(
                                  label: 'Parse jobs not yet parsed',
                                  count: _status!.cloudPendingParseJobCount,
                                )
                              else
                                Text(
                                  'Cloud queue empty',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_status!.hasCloudLocalMismatch) ...[
                      const SizedBox(height: AppSpacing.item),
                      Card(
                        color: Theme.of(context)
                            .colorScheme
                            .tertiaryContainer
                            .withValues(alpha: 0.35),
                        child: ListTile(
                          leading: Icon(
                            Icons.cloud_sync_outlined,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          title: const Text('Cloud queue needs a sync'),
                          subtitle: Text(
                            '${_status!.cloudPendingParseJobCount} SMS in Firebase; '
                            'tap Sync and parse now to download and run the parser.',
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.item),
                  _MetaRow(
                    label: 'Last sync',
                    value: _formatTime(_status?.lastSyncAt),
                  ),
                  const SizedBox(height: AppSpacing.tight),
                  _MetaRow(
                    label: 'Last ingest',
                    value: _formatTime(_status?.lastIngestAt),
                  ),
                  if ((_status?.failedParseCount ?? 0) > 0) ...[
                    const SizedBox(height: AppSpacing.item),
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.35),
                      child: ListTile(
                        leading: Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          '${_status!.failedParseCount} parse(s) failed on last sync',
                        ),
                        subtitle: const Text(
                          'Check SMS format or payment source hints',
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.item),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  FilledButton.icon(
                    onPressed: _loading ? null : _syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync and parse now'),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  AppSectionHeader(
                    title: 'Paste missed SMS',
                    subtitle: 'Separate messages with a blank line',
                  ),
                  TextField(
                    controller: _pasteController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'Rs.500 debited from A/c **1234...\n\nRs.899 spent on card **4567...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  FilledButton.tonal(
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
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      _lastSubmitMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.connectSms),
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('SMS setup guide'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          AppStatusChip(
            label: '$count',
            tone: AppStatTone.warning,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
