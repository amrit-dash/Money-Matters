import 'package:flutter/material.dart';

import '../../app_router.dart';
import 'auth_screen.dart';
import 'onboarding_state.dart';
import 'payment_sources_screen.dart';
import 'shortcuts_setup_screen.dart';

/// Multi-step onboarding: auth → payment sources → Shortcuts setup.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.state});

  final OnboardingState? state;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingState _state;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? OnboardingState();
    if (_state.isAuthenticated) _step = 1;
    if (_state.paymentSourcesComplete) _step = 2;
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => AuthScreen(
          state: _state,
          onContinue: () => setState(() => _step = 1),
        ),
      1 => PaymentSourcesScreen(
          state: _state,
          onContinue: () => setState(() => _step = 2),
        ),
      2 => ShortcutsSetupScreen(
          state: _state,
          onComplete: _goToDashboard,
        ),
      _ => AuthScreen(
          state: _state,
          onContinue: () => setState(() => _step = 1),
        ),
    };
  }
}
