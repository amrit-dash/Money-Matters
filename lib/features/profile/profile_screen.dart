import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../core/auth/auth_service.dart';

/// Lightweight settings hub: accounts, SMS setup, sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
  });

  final AuthService authService;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await authService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          if (email != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                ),
              ),
              title: Text(email),
              subtitle: const Text('Signed in'),
            )
          else
            const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Signed in'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Accounts'),
            subtitle: const Text('Banks and cards for SMS matching'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRoutes.accounts),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined),
            title: const Text('Connect SMS'),
            subtitle: const Text('Shortcuts setup and device token'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRoutes.connectSms),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
