import 'package:flutter/material.dart';

/// Wraps app content and shows a Done bar above the keyboard when visible.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final showBar = bottomInset > 0;

    return Stack(
      children: [
        child,
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Material(
              elevation: 2,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
