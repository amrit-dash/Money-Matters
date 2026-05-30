import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import 'onboarding_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.state,
    required this.onContinue,
    this.authService,
  });

  final OnboardingState state;
  final VoidCallback onContinue;
  final AuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final AuthService _auth;
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setError(Object e) {
    final message = e is FirebaseAuthException
        ? e.message ?? e.code
        : e.toString();
    setState(() => _error = message);
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      widget.state.setCredentials(email: email, password: password);
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _setError(StateError('Signed in but no user id'));
        return;
      }
      await widget.state.markAuthenticated(uid: uid);
      if (!mounted) return;
      widget.onContinue();
    } catch (e) {
      _setError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cred = await _auth.signInWithGoogle();
      final email = cred.user?.email ?? '';
      widget.state.setCredentials(email: email, password: '');
      final uid = cred.user?.uid;
      if (uid == null) {
        _setError(StateError('Google sign-in succeeded but no user id'));
        return;
      }
      await widget.state.markAuthenticated(uid: uid);
      if (!mounted) return;
      widget.onContinue();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'sign-in-cancelled') _setError(e);
    } catch (e) {
      _setError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingStepIndicator(
                  currentStep: 0,
                  totalSteps: 3,
                  labels: ['Sign in', 'Accounts', 'Connect SMS'],
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Money Matters',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.tight),
                Text(
                  'Track spend from bank SMS. Your data stays in your Firebase project.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.section),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: AppSpacing.section),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or email',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.item),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'New here? Create account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
