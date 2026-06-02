import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/firebase_options.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/app_services.dart';
import '../../services/user_data_deletion_service.dart';
import 'appearance_settings_section.dart';
import 'llm_logs_screen.dart';

/// Lightweight settings hub: accounts, SMS setup, sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.userDataDeletionService,
    this.embeddedInShell = false,
  });

  final AuthService authService;
  final UserDataDeletionService userDataDeletionService;
  final bool embeddedInShell;

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

  Future<void> _deleteAllData(BuildContext context) async {
    final confirmed = await _confirmDeleteAllData(context);
    if (!confirmed || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await userDataDeletionService.deleteAllUserData();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All your data has been deleted. Your account is still signed in.'),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.dashboard,
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete data: $e')),
      );
    }
  }

  Future<bool> _confirmDeleteAllData(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently removes all transactions, SMS ingests, accounts, '
          'categories, and device tokens from this device and the cloud.\n\n'
          'Your sign-in account is kept — you can sign out separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return false;

    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _TypeDeleteDialog(),
    );
    return typed == true;
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
      appBar: AppBar(
        automaticallyImplyLeading: !embeddedInShell,
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            heroGradient: true,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onPrimaryContainer
                                    .withValues(alpha: 0.85),
                              ),
                        ),
                      ],
                      if (projectId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Firebase: $projectId',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onPrimaryContainer
                                    .withValues(alpha: 0.85),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const AppearanceSettingsSection(),
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: 'AI / Agent',
            subtitle: 'LLM provider, API key, and model for auto-classify',
          ),
          const SizedBox(height: AppSpacing.tight),
          AppMenuTile(
            icon: Icons.smart_toy_outlined,
            title: 'Agent settings',
            subtitle: 'Enable LLM, pick provider, test API key, choose model',
            onTap: () => Navigator.pushNamed(context, AppRoutes.agentSettings),
          ),
          const SizedBox(height: AppSpacing.tight),
          AppMenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'LLM logs & errors',
            subtitle: 'Cloud classify, test key, and fetch model events',
            onTap: () {
              final logs = AppScope.of(context).llmLogsService;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LlmLogsScreen(llmLogsService: logs),
                ),
              );
            },
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
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(title: 'Danger zone'),
          const SizedBox(height: AppSpacing.tight),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            onPressed: () => _deleteAllData(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all data'),
          ),
          const SizedBox(height: 4),
          Text(
            'Removes all ledger data from this device and cloud. '
            'Your sign-in is not affected.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _TypeDeleteDialog extends StatefulWidget {
  @override
  State<_TypeDeleteDialog> createState() => _TypeDeleteDialogState();
}

class _TypeDeleteDialogState extends State<_TypeDeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == 'DELETE';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Type DELETE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This action cannot be undone. Type DELETE in capital letters.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Confirmation',
              hintText: 'DELETE',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            disabledBackgroundColor: scheme.error.withValues(alpha: 0.4),
          ),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete all data'),
        ),
      ],
    );
  }
}
