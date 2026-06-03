import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/auth/auth_service.dart';
import '../parse/llm_parser.dart';
import '../models/llm_settings.dart';

/// Loads and saves BYOK LLM settings under `users/{uid}/settings/llm`.
class LlmSettingsService {
  LlmSettingsService({
    required AuthService authService,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.region = 'asia-south1',
  })  : _auth = authService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: region);

  final AuthService _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String region;

  LlmSettings? _cache;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('llm');

  Future<LlmSettings> load({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;
    final uid = _auth.uid;
    if (uid == null) return const LlmSettings();

    final snap = await _doc(uid).get();
    _cache = LlmSettings.fromFirestore(snap.data());
    return _cache!;
  }

  void invalidateCache() => _cache = null;

  Stream<LlmSettings> watch() {
    final uid = _auth.uid;
    if (uid == null) {
      return Stream.value(const LlmSettings());
    }
    return _doc(uid).snapshots().map((snap) {
      final settings = LlmSettings.fromFirestore(snap.data());
      _cache = settings;
      return settings;
    });
  }

  Future<void> save(LlmSettings settings) async {
    final uid = _auth.requireUid();
    await _doc(uid).set(settings.toFirestore(), SetOptions(merge: true));
    _cache = settings.copyWith(updatedAt: DateTime.now().toUtc());
    ClassifierDiagnostics.clearNeedsConfigBackoff();
  }

  Future<void> testApiKey(LlmSettings settings) async {
    await _callable('testLlmApiKey').call(settings.toCallablePayload());
  }

  Future<List<String>> fetchModels(LlmSettings settings) async {
    final response = await _callable('fetchLlmModels')
        .call<Map<String, dynamic>>(settings.toCallablePayload());
    final data = Map<String, dynamic>.from(response.data);
    final raw = data['models'];
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
      ..sort();
  }

  HttpsCallable _callable(String name) =>
      _functions.httpsCallable(name);

  /// Whether auto-classify should invoke Cloud Functions.
  Future<bool> isLlmEnabled() async {
    final settings = await load();
    return settings.enabled && settings.isConfigured;
  }
}
