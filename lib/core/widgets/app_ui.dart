import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

export '../theme/app_theme.dart' show AppSpacing, AppStatTone, AppRadii;

/// Standard surface card — 16px radius, outline, optional hero gradient.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.heroGradient = false,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool heroGradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = color ?? scheme.surfaceContainerLow;

    Widget content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.85),
        ),
        color: heroGradient ? null : baseColor,
        gradient: heroGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.55),
                  scheme.secondaryContainer.withValues(alpha: 0.35),
                ],
              )
            : null,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadii.badge),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AppStatTone.neutral,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppStatTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final (bg, fg) = appToneColors(scheme, tone);

    return AppCard(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppIconBadge(icon: icon, background: bg, foreground: fg),
          const SizedBox(height: AppSpacing.item),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primaryContainer.withValues(alpha: 0.65),
                        scheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Icon(icon, size: 40, color: scheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.tight),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (primaryAction != null) ...[
            const SizedBox(height: AppSpacing.section),
            primaryAction!,
          ],
          if (secondaryAction != null) ...[
            const SizedBox(height: AppSpacing.tight),
            secondaryAction!,
          ],
        ],
      ),
    );
  }
}

class AppMenuTile extends StatelessWidget {
  const AppMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final accent = destructive ? scheme.error : scheme.primary;
    final titleColor = destructive ? scheme.error : scheme.onSurface;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _AppIconBadge(
          icon: icon,
          background: destructive
              ? scheme.errorContainer.withValues(alpha: 0.65)
              : scheme.primaryContainer.withValues(alpha: 0.55),
          foreground: destructive ? scheme.onErrorContainer : accent,
          compact: true,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(color: titleColor),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.outline,
        ),
      ),
    );
  }
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.tone = AppStatTone.neutral,
    this.showDot = true,
  });

  final String label;
  final AppStatTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = appToneColors(scheme, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: fg.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final active = index <= currentStep;
            final current = index == currentStep;
            return Expanded(
              child: Container(
                height: current ? 5 : 4,
                margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: active
                      ? LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        )
                      : null,
                  color: active ? null : scheme.surfaceContainerHighest,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.tight),
        Text(
          'Step ${currentStep + 1} of $totalSteps · ${labels[currentStep]}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Label + amount pair shown below the hero total on [HeroSpendCard].
class HeroSpendMetric {
  const HeroSpendMetric({required this.label, required this.amount});

  final String label;
  final String amount;
}

/// Large hero metric for dashboard spend / income.
class HeroSpendCard extends StatelessWidget {
  const HeroSpendCard({
    super.key,
    required this.label,
    required this.amount,
    this.secondaryLabel,
    this.secondaryAmount,
    this.additionalMetrics = const [],
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final String label;
  final String amount;
  final String? secondaryLabel;
  final String? secondaryAmount;
  final List<HeroSpendMetric> additionalMetrics;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AppCard(
      heroGradient: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.onPrimaryContainer, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
              height: 1.1,
            ),
          ),
          ..._buildMetricRows(
            theme,
            scheme,
            [
              if (secondaryLabel != null && secondaryAmount != null)
                HeroSpendMetric(
                  label: secondaryLabel!,
                  amount: secondaryAmount!,
                ),
              ...additionalMetrics,
            ],
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildMetricRows(
    ThemeData theme,
    ColorScheme scheme,
    List<HeroSpendMetric> metrics,
  ) {
    if (metrics.isEmpty) return const [];

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
    );
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
      fontWeight: FontWeight.w600,
    );

    return [
      const SizedBox(height: AppSpacing.item),
      for (final metric in metrics) ...[
        Text(metric.label, style: labelStyle),
        const SizedBox(height: 2),
        Text(metric.amount, style: amountStyle),
        if (metric != metrics.last) const SizedBox(height: AppSpacing.tight),
      ],
    ];
  }
}

class AppWelcomeHero extends StatelessWidget {
  const AppWelcomeHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.savings_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      heroGradient: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadii.badge),
            ),
            child: Icon(icon, size: 32, color: scheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppPageBody extends StatelessWidget {
  const AppPageBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: child,
    );
  }
}

class _AppIconBadge extends StatelessWidget {
  const _AppIconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
    this.compact = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 40.0;
    final iconSize = compact ? 18.0 : 20.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
