import 'package:flutter/widgets.dart';

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import '../features/dashboard/dashboard_repository.dart';
import '../features/dashboard/local_dashboard_repository.dart';
import '../features/recovery/local_recovery_repository.dart';
import '../features/recovery/recovery_repository.dart';
import '../features/review/local_review_repository.dart';
import '../features/review/review_repository.dart';
import '../ingest/ingest_queue_drain.dart';
import '../ingest/ingest_repository.dart';
import 'category_service.dart';
import 'ingest_parse_pipeline.dart';
import 'payment_source_service.dart';

/// Root dependency container for Money Matters.
class AppServices {
  AppServices({
    required this.authService,
    required this.localDatabase,
    required this.ingestRepository,
    required this.queueDrain,
    required this.parsePipeline,
    required this.paymentSourceService,
    required this.categoryService,
    DashboardRepository? dashboardRepository,
    ReviewRepository? reviewRepository,
    RecoveryRepository? recoveryRepository,
  })  : dashboardRepository = dashboardRepository ??
            LocalDashboardRepository(
              localDatabase: localDatabase,
              categoryService: categoryService,
            ),
        reviewRepository = reviewRepository ??
            LocalReviewRepository(
              localDatabase: localDatabase,
              authService: authService,
              categoryService: categoryService,
            ),
        recoveryRepository = recoveryRepository ??
            LocalRecoveryRepository(
              localDatabase: localDatabase,
              ingestRepository: ingestRepository,
              queueDrain: queueDrain,
              authService: authService,
            );

  final AuthService authService;
  final LocalDatabase localDatabase;
  final IngestRepository ingestRepository;
  final IngestQueueDrain queueDrain;
  final IngestParsePipeline parsePipeline;
  final PaymentSourceService paymentSourceService;
  final CategoryService categoryService;
  final DashboardRepository dashboardRepository;
  final ReviewRepository reviewRepository;
  final RecoveryRepository recoveryRepository;
}

/// InheritedWidget exposing [AppServices] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services != oldWidget.services;
}
