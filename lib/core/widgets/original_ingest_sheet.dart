import 'package:flutter/material.dart';

import '../../core/db/local_database.dart';
import '../theme/app_theme.dart';

/// Shows the raw SMS body (and sender) for a transaction's linked ingest.
Future<void> showOriginalIngestSheet(
  BuildContext context, {
  required LocalDatabase localDatabase,
  required String rawIngestId,
}) async {
  final row = await localDatabase.getRawIngest(rawIngestId);
  if (!context.mounted) return;

  final body = row?['body'] as String?;
  final sender = row?['sender'] as String? ?? '';
  final receivedAt = row?['received_at'] as String?;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.page,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Original SMS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (body == null || body.isEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  Text(
                    'Original message not found on this device. '
                    'Try Recovery → Sync and parse now to download SMS from cloud.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else ...[
                  if (sender.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      'From: $sender',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (receivedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Received: $receivedAt',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.item),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          body,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
