import 'package:flutter/material.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/connect_sms_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/recovery/recovery_screen.dart';
import 'features/review/review_screen.dart';

/// Named routes for Money Matters.
class AppRoutes {
  static const onboarding = '/onboarding';
  static const connectSms = '/connect-sms';
  static const dashboard = '/dashboard';
  static const review = '/review';
  static const recovery = '/recovery';
}

/// Builds [MaterialApp] routes. Coordinator wires [initialRoute] from auth state.
class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OnboardingFlow(),
        );
      case AppRoutes.connectSms:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ConnectSmsScreen(),
        );
      case AppRoutes.dashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DashboardScreen(),
        );
      case AppRoutes.review:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReviewScreen(),
        );
      case AppRoutes.recovery:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RecoveryScreen(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OnboardingFlow(),
        );
    }
  }

  /// Deep link handler for `moneymatters://recovery` (Shortcut B).
  static String? routeFromUri(Uri uri) {
    if (uri.scheme != 'moneymatters') return null;
    switch (uri.host) {
      case 'recovery':
        return AppRoutes.recovery;
      case 'ingest':
        // URL ingest handled by ingest layer; optionally refresh dashboard.
        return AppRoutes.dashboard;
      default:
        return null;
    }
  }
}
