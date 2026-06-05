import 'package:flutter/material.dart';

import 'app_ui.dart';

/// Standard loading / error / data handling for [StreamBuilder] bodies.
class StreamStateView<T> extends StatelessWidget {
  const StreamStateView({
    super.key,
    required this.snapshot,
    required this.builder,
    this.loading,
    this.onRetry,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load data',
            message: snapshot.error.toString(),
            primaryAction: onRetry == null
                ? null
                : FilledButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
          ),
        ),
      );
    }

    if (!snapshot.hasData) {
      return loading ??
          const Center(child: CircularProgressIndicator());
    }

    return builder(snapshot.data as T);
  }
}
