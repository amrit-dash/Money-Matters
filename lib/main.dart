import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_router.dart';
import 'core/auth/auth_service.dart';
import 'core/config/firebase_options.dart';
import 'features/setup/firebase_setup_screen.dart';
import 'core/db/local_database.dart';
import 'ingest/ingest_queue_drain.dart';
import 'ingest/ingest_repository.dart';
import 'ingest/url_ingest_handler.dart';
import 'services/ingest_parse_pipeline.dart';

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
  final parsePipeline = IngestParsePipeline(
    localDatabase: localDatabase,
    authService: authService,
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

  runApp(
    MoneyMattersApp(
      authService: authService,
      queueDrain: queueDrain,
      urlIngestHandler: urlIngestHandler,
    ),
  );
}

class MoneyMattersApp extends StatefulWidget {
  const MoneyMattersApp({
    super.key,
    required this.authService,
    required this.queueDrain,
    required this.urlIngestHandler,
  });

  final AuthService authService;
  final IngestQueueDrain queueDrain;
  final UrlIngestHandler urlIngestHandler;

  @override
  State<MoneyMattersApp> createState() => _MoneyMattersAppState();
}

class _MoneyMattersAppState extends State<MoneyMattersApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.urlIngestHandler.start();

    widget.urlIngestHandler.onRecoveryUrl.listen((_) {
      _navigatorKey.currentState?.pushNamed(AppRoutes.recovery);
    });

    widget.authService.authStateChanges.listen((user) async {
      if (user != null) {
        await widget.queueDrain.drainIfAuthenticated();
      }
    });

    if (widget.authService.isSignedIn) {
      await widget.queueDrain.drainIfAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute =
        widget.authService.isSignedIn ? AppRoutes.dashboard : AppRoutes.onboarding;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Money Matters',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
