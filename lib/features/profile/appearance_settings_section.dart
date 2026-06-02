import 'package:flutter/material.dart';

import '../../core/theme/app_accent.dart';
import '../../core/theme/theme_scope.dart';
import '../../core/widgets/app_ui.dart';

/// Profile controls for theme mode and accent color.
class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Appearance',
          subtitle: 'Theme and accent color',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.item),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {controller.themeMode},
                  onSelectionChanged: (selection) {
                    controller.setThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Accent color',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.item),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final accent in AppAccent.values)
                      _AccentChip(
                        accent: accent,
                        selected: controller.accent == accent,
                        onTap: () => controller.setAccent(accent),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.tight),
                Text(
                  'Applies across dashboards, cards, and buttons.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewScheme = ColorScheme.fromSeed(seedColor: accent.seedColor);

    return Semantics(
      button: true,
      selected: selected,
      label: accent.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: previewScheme.primary,
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: previewScheme.onPrimary,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                accent.label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
