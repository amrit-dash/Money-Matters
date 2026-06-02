import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_router.dart';
import 'core/auth/auth_service.dart';
import 'core/widgets/keyboard_done_bar.dart';
import 'core/config/firebase_options.dart';
import 'core/db/local_database.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_scope.dart';
import 'features/setup/firebase_setup_screen.dart';
import 'ingest/ingest_queue_drain.dart';
import 'ingest/ingest_repository.dart';
import 'ingest/url_ingest_handler.dart';
import 'parse/llm_parser.dart';
import 'services/app_services.dart';
import 'services/category_service.dart';
import 'services/fcm_service.dart';
import 'services/ingest_parse_pipeline.dart';
import 'services/payment_source_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const FirebaseSetupScreen());
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final authService = AuthService();
  final localDatabase = LocalDatabase();
  final paymentSourceService = PaymentSourceService(authService: authService);
  final categoryService = CategoryService(authService: authService);
  final parsePipeline = IngestParsePipeline(
    localDatabase: localDatabase,
    authService: authService,
    paymentSourceService: paymentSourceService,
    categoryService: categoryService,
    classifier: CloudFunctionsClassifier(),
  );
  final ingestRepository = IngestRepository(
    authService: authService,
    localDatabase: localDatabase,
  );
  final queueDrain = IngestQueueDrain(
    repository: ingestRepository,
    authService: authService,
    parsePipeline: parsePipeline,
  );
  final urlIngestHandler = UrlIngestHandler(queueDrain: queueDrain);
  final fcmService = FcmService(authService: authService);
  final appServices = AppServices(
    authService: authService,
    localDatabase: localDatabase,
    ingestRepository: ingestRepository,
    queueDrain: queueDrain,
    parsePipeline: parsePipeline,
    paymentSourceService: paymentSourceService,
    categoryService: categoryService,
    transactionClassifier: CloudFunctionsClassifier(),
  );
  appServices.firestoreRealtimeSync.start();
  final themeController = ThemeController();
  await themeController.load();

  runApp(
    AppScope(
      services: appServices,
      child: ThemeScope(
        notifier: themeController,
        child: MoneyMattersApp(
          authService: authService,
          queueDrain: queueDrain,
          urlIngestHandler: urlIngestHandler,
          fcmService: fcmService,
          themeController: themeController,
        ),
      ),
    ),
  );
}

class MoneyMattersApp extends StatefulWidget {
  const MoneyMattersApp({
    super.key,
    required this.authService,
    required this.queueDrain,
    required this.urlIngestHandler,
    required this.fcmService,
    required this.themeController,
  });

  final AuthService authService;
  final IngestQueueDrain queueDrain;
  final UrlIngestHandler urlIngestHandler;
  final FcmService fcmService;
  final ThemeController themeController;

  @override
  State<MoneyMattersApp> createState() => _MoneyMattersAppState();
}

class _MoneyMattersAppState extends State<MoneyMattersApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late bool _isSignedIn;

  @override
  void initState() {
    super.initState();
    _isSignedIn = widget.authService.isSignedIn;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.urlIngestHandler.start();

    widget.urlIngestHandler.onRecoveryUrl.listen((_) {
      _navigatorKey.currentState?.pushNamed(AppRoutes.recovery);
    });

    widget.fcmService.attachHandlers(onClassify: _openClassify);

    widget.authService.authStateChanges.listen((user) async {
      final signedIn = user != null;
      if (signedIn != _isSignedIn && mounted) {
        setState(() => _isSignedIn = signedIn);
      }

      if (signedIn) {
        await widget.fcmService.registerForUser();
        await widget.queueDrain.drainIfAuthenticated();
      } else {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.onboarding,
          (route) => false,
        );
      }
    });

    if (widget.authService.isSignedIn) {
      await widget.fcmService.registerForUser();
      await widget.queueDrain.drainIfAuthenticated();
    }
  }

  /// Deep-links a tapped classify notification to the classify flow.
  void _openClassify(String txId) {
    _navigatorKey.currentState?.pushNamed(AppRoutes.classify, arguments: txId);
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute =
        _isSignedIn ? AppRoutes.dashboard : AppRoutes.onboarding;

    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Money Matters',
          theme: widget.themeController.lightTheme,
          darkTheme: widget.themeController.darkTheme,
          themeMode: widget.themeController.themeMode,
          initialRoute: initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) => KeyboardDoneBar(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
