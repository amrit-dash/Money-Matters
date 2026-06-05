import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/onboarding/onboarding_progress_store.dart';
import 'onboarding_state.dart';
import 'shortcuts_setup_screen.dart';

/// Connect SMS — usable from onboarding or later from the dashboard.
class ConnectSmsScreen extends StatefulWidget {
  const ConnectSmsScreen({
    super.key,
    this.state,
    this.authService,
    this.showFinishOnboarding = false,
  });

  final OnboardingState? state;
  final AuthService? authService;
  final bool showFinishOnboarding;

  @override
  State<ConnectSmsScreen> createState() => _ConnectSmsScreenState();
}

class _ConnectSmsScreenState extends State<ConnectSmsScreen> {
  late final OnboardingState _state;
  late final AuthService _auth;
  bool _syncing = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? OnboardingState();
    _auth = widget.authService ?? AuthService();
    _syncDeviceRegistration();
  }

  Future<void> _syncDeviceRegistration() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() => _syncError = 'Sign in to register this device for SMS ingest.');
        return;
      }
      await _state.ensureIngestDeviceRegistered(uid: uid);
    } catch (e) {
      setState(() => _syncError = 'Could not register device: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connect SMS')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Syncing device token to Firebase…'),
            ],
          ),
        ),
      );
    }

    if (_syncError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connect SMS')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_syncError!, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _syncDeviceRegistration,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ShortcutsSetupScreen(
      state: _state,
      onComplete: () async {
        if (widget.showFinishOnboarding) {
          final uid = _auth.currentUser?.uid;
          if (uid != null) {
            await OnboardingProgressStore().markComplete(uid);
          }
          if (!context.mounted) return;
          AppRouter.goToDashboard(context);
        } else {
          Navigator.of(context).pop();
        }
      },
      showFinishOnboarding: widget.showFinishOnboarding,
    );
  }
}
