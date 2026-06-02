import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_ui.dart';
import '../../models/llm_log_entry.dart';
import '../../services/llm_logs_service.dart';

/// Recent LLM events written by Cloud Functions under `users/{uid}/llm_logs`.
class LlmLogsScreen extends StatelessWidget {
  const LlmLogsScreen({
    super.key,
    required this.llmLogsService,
  });

  final LlmLogsService llmLogsService;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM logs'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear logs?'),
                  content: const Text(
                    'Removes all stored LLM log entries from the cloud.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await llmLogsService.clearAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs cleared')),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<LlmLogEntry>>(
        stream: llmLogsService.watchRecent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(
                  'No LLM events yet. Errors and warnings appear here when '
                  'auto-classify runs with LLM enabled.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: logs.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.tight),
            itemBuilder: (context, index) {
              final log = logs[index];
              final tone = log.isError
                  ? AppStatTone.error
                  : log.isWarning
                      ? AppStatTone.warning
                      : AppStatTone.neutral;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.message,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          AppStatusChip(label: log.level, tone: tone),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeFormat.format(log.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      if (log.source != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Source: ${log.source}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (log.provider != null) ...[
                        Text(
                          'Provider: ${log.provider}'
                          '${log.model != null ? ' · ${log.model}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (log.detail != null && log.detail!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.tight),
                        Text(
                          log.detail!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
