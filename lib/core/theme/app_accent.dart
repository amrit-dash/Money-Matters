import 'package:flutter/material.dart';

/// User-selectable Material 3 seed colors.
enum AppAccent {
  teal('teal', 'Teal', Color(0xFF00897B)),
  indigo('indigo', 'Indigo', Color(0xFF3F51B5)),
  amber('amber', 'Amber', Color(0xFFFFA000)),
  rose('rose', 'Rose', Color(0xFFE91E63)),
  green('green', 'Green', Color(0xFF2E7D32)),
  blue('blue', 'Blue', Color(0xFF1565C0)),
  violet('violet', 'Violet', Color(0xFF6E5FD4));

  const AppAccent(this.id, this.label, this.seedColor);

  final String id;
  final String label;
  final Color seedColor;

  static AppAccent fromId(String? id) {
    for (final accent in AppAccent.values) {
      if (accent.id == id) return accent;
    }
    return AppAccent.teal;
  }
}
