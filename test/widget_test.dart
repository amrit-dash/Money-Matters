import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/app_router.dart';

void main() {
  test('AppRoutes define core navigation paths', () {
    expect(AppRoutes.onboarding, '/onboarding');
    expect(AppRoutes.dashboard, '/dashboard');
    expect(AppRoutes.profile, '/profile');
    expect(AppRoutes.accounts, '/accounts');
    expect(AppRoutes.agentSettings, '/agent-settings');
  });
}
