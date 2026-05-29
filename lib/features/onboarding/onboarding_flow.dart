import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../services/payment_source_service.dart';
import 'auth_screen.dart';
import 'onboarding_state.dart';
import 'payment_sources_screen.dart';
import 'connect_sms_screen.dart';

/// Multi-step onboarding: auth → payment sources → Shortcuts setup.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    this.state,
    required this.authService,
    required this.paymentSourceService,
  });

  final OnboardingState? state;
  final AuthService authService;
  final PaymentSourceService paymentSourceService;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingState _state;
  int _step = 0;
  bool _loadingSources = false;

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? OnboardingState();
    if (_state.isAuthenticated) {
      _step = 1;
      _loadPaymentSources();
    }
    if (_state.paymentSourcesComplete) _step = 2;
  }

  Future<void> _loadPaymentSources() async {
    setState(() => _loadingSources = true);
    try {
      await _state.loadPaymentSources(widget.paymentSourceService);
    } finally {
      if (mounted) setState(() => _loadingSources = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSources) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return switch (_step) {
      0 => AuthScreen(
          state: _state,
          authService: widget.authService,
          onContinue: () {
            setState(() => _step = 1);
            _loadPaymentSources();
          },
        ),
      1 => PaymentSourcesScreen(
          state: _state,
          paymentSourceService: widget.paymentSourceService,
          onContinue: () => setState(() => _step = 2),
        ),
      2 => ConnectSmsScreen(
          state: _state,
          authService: widget.authService,
          showFinishOnboarding: true,
        ),
      _ => AuthScreen(
          state: _state,
          authService: widget.authService,
          onContinue: () => setState(() => _step = 1),
        ),
    };
  }
}
