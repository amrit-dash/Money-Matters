import 'package:flutter/material.dart';

import 'features/accounts/accounts_screen.dart';
import 'core/widgets/app_shell.dart';
import 'features/onboarding/connect_sms_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/profile/agent_settings_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/recovery/recovery_screen.dart';
import 'features/review/classify_screen.dart';
import 'features/review/review_screen.dart';
import 'services/app_services.dart';

/// Named routes for Money Matters.
class AppRoutes {
  static const onboarding = '/onboarding';
  static const connectSms = '/connect-sms';
  static const dashboard = '/dashboard';
  static const review = '/review';
  static const classify = '/classify';
  static const recovery = '/recovery';
  static const profile = '/profile';
  static const accounts = '/accounts';
  static const agentSettings = '/agent-settings';
}

/// Builds [MaterialApp] routes. Coordinator wires [initialRoute] from auth state.
class AppRouter {
  /// Makes dashboard the sole route — no back stack to onboarding/login.
  static void goToDashboard(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  /// Clears the stack and shows onboarding after sign-out.
  static void goToOnboarding(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (route) => false,
    );
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => OnboardingFlow(
            authService: AppScope.of(ctx).authService,
            paymentSourceService: AppScope.of(ctx).paymentSourceService,
          ),
        );
      case AppRoutes.connectSms:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => ConnectSmsScreen(
            authService: AppScope.of(ctx).authService,
          ),
        );
      case AppRoutes.dashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) {
            final services = AppScope.of(ctx);
            return AppShell(
              dashboardRepository: services.dashboardRepository,
              reviewRepository: services.reviewRepository,
              categoryService: services.categoryService,
              paymentSourceService: services.paymentSourceService,
              recoveryRepository: services.recoveryRepository,
              queueDrain: services.queueDrain,
              authService: services.authService,
              userDataDeletionService: services.userDataDeletionService,
            );
          },
        );
      case AppRoutes.review:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => ReviewScreen(
            repository: AppScope.of(ctx).reviewRepository,
            queueDrain: AppScope.of(ctx).queueDrain,
          ),
        );
      case AppRoutes.classify:
        final txId = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) {
            if (txId == null) {
              return ReviewScreen(repository: AppScope.of(ctx).reviewRepository);
            }
            return ClassifyScreen(
              repository: AppScope.of(ctx).reviewRepository,
              paymentSourceService: AppScope.of(ctx).paymentSourceService,
              transactionId: txId,
            );
          },
        );
      case AppRoutes.recovery:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => RecoveryScreen(
            repository: AppScope.of(ctx).recoveryRepository,
          ),
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) {
            final services = AppScope.of(ctx);
            return ProfileScreen(
              authService: services.authService,
              userDataDeletionService: services.userDataDeletionService,
            );
          },
        );
      case AppRoutes.accounts:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => AccountsScreen(
            paymentSourceService: AppScope.of(ctx).paymentSourceService,
            queueDrain: AppScope.of(ctx).queueDrain,
          ),
        );
      case AppRoutes.agentSettings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) {
            final services = AppScope.of(ctx);
            return AgentSettingsScreen(
              llmSettingsService: services.llmSettingsService,
            );
          },
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => OnboardingFlow(
            authService: AppScope.of(ctx).authService,
            paymentSourceService: AppScope.of(ctx).paymentSourceService,
          ),
        );
    }
  }

  /// Deep link handler for `moneymatters://recovery` (Shortcut B) and
  /// `moneymatters://classify?txId=...` (tapped FCM classify prompt).
  static String? routeFromUri(Uri uri) {
    if (uri.scheme != 'moneymatters') return null;
    switch (uri.host) {
      case 'recovery':
        return AppRoutes.recovery;
      case 'classify':
        return AppRoutes.classify;
      case 'ingest':
        return AppRoutes.dashboard;
      default:
        return null;
    }
  }
}
