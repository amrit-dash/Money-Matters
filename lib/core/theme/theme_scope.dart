import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

/// Exposes [ThemeController] to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}
