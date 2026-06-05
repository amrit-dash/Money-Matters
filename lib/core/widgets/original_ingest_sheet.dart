import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/db/local_database.dart';
import '../../ingest/ingest_repository.dart';
import '../theme/app_theme.dart';

/// Shows the raw SMS body (and sender) for a transaction's linked ingest.
Future<void> showOriginalIngestSheet(
  BuildContext context, {
  required LocalDatabase localDatabase,
  required String rawIngestId,
  IngestRepository? ingestRepository,
}) async {
  if (rawIngestId.isNotEmpty && ingestRepository != null) {
    await ingestRepository.ensureRawIngestMirrored(rawIngestId);
  }

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
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
      final receivedLabel = _formatReceivedAt(receivedAt);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.page,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Original SMS',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                if (body == null || body.isEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  Text(
                    'Original message not found on this device. '
                    'Try Recovery → Sync and parse now to download SMS from cloud.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else ...[
                  if (sender.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      'From: $sender',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (receivedLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Received: $receivedLabel',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.item),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppRadii.control),
                          border: Border.all(
                            color: scheme.outlineVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            body,
                            style: Theme.of(ctx)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String? _formatReceivedAt(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('d MMM yyyy, h:mm a').format(parsed.toLocal());
}
