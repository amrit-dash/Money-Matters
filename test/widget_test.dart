import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/app_router.dart';
import 'package:money_matters/core/config/firebase_options.dart';

void main() {
  test('Firebase options are configured for money-matters-amrit', () {
    expect(DefaultFirebaseOptions.isConfigured, isTrue);
    expect(DefaultFirebaseOptions.ios.projectId, 'money-matters-amrit');
    expect(DefaultFirebaseOptions.ios.iosClientId, isNotNull);
  });

  test('AppRoutes define core navigation paths', () {
    expect(AppRoutes.onboarding, '/onboarding');
    expect(AppRoutes.dashboard, '/dashboard');
    expect(AppRoutes.profile, '/profile');
    expect(AppRoutes.accounts, '/accounts');
  });
}
