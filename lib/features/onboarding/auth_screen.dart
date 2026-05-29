import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
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
      widget.state.markAuthenticated();
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
      widget.state.markAuthenticated();
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
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Money Matters',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in with Google or email. Data stays in your Firebase project.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
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
