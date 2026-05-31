import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/firebase_options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';

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
    // Navigation is handled by [MoneyMattersApp]'s auth listener in main.dart.
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email;
    final uid = authService.currentUser?.uid;
    final projectId = DefaultFirebaseOptions.isConfigured
        ? DefaultFirebaseOptions.currentPlatform.projectId
        : null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: Text(
                      email != null && email.isNotEmpty
                          ? email[0].toUpperCase()
                          : '?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email ?? 'Signed in',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        AppStatusChip(
                          label: 'Active session',
                          tone: AppStatTone.success,
                        ),
                        if (uid != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'UID: $uid',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (projectId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Firebase: $projectId',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(title: 'Setup'),
          AppMenuTile(
            icon: Icons.account_balance_outlined,
            title: 'Accounts',
            subtitle: 'Banks and cards for SMS matching',
            onTap: () => Navigator.pushNamed(context, AppRoutes.accounts),
          ),
          const SizedBox(height: AppSpacing.tight),
          AppMenuTile(
            icon: Icons.sms_outlined,
            title: 'Connect SMS',
            subtitle: 'Shortcuts automation and device token',
            onTap: () => Navigator.pushNamed(context, AppRoutes.connectSms),
          ),
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(title: 'Account'),
          AppMenuTile(
            icon: Icons.logout,
            title: 'Sign out',
            onTap: () => _signOut(context),
            destructive: true,
          ),
        ],
      ),
    );
  }
}
