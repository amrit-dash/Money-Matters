import 'package:flutter/material.dart';

/// Shown when [DefaultFirebaseOptions.isConfigured] is false.
/// Points the user to manual setup steps on a physical iPhone.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  static const setupDocPath = 'docs/SETUP-IPHONE.md';

  static const _steps = [
    'Create a Firebase project (Auth, Firestore, Blaze plan)',
    'Deploy functions: cd firebase && npm ci && firebase deploy',
    'Download GoogleService-Info.plist → ios/Runner/',
    'Run flutterfire configure (see SETUP-IPHONE.md for exact command)',
    'Install on iPhone via Xcode or ./scripts/build_ipa.sh',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MaterialApp(
      title: 'Money Matters — Setup',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Setup required')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Firebase is not configured',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This build uses a placeholder firebase_options.dart. '
              'Complete setup on your Mac before testing on a physical iPhone.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Quick checklist', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(_steps.length, (i) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}', style: theme.textTheme.labelSmall),
                ),
                title: Text(_steps[i]),
                dense: true,
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Full guide', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SelectableText(
                      setupDocPath,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open this file in the repo root for step-by-step instructions, '
                      'including Xcode signing and Shortcuts setup.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Verify locally: ./scripts/verify_setup.sh',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
