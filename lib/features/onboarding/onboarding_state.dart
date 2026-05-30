import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:money_matters/core/auth/device_credentials_store.dart';
import 'package:money_matters/core/auth/device_token_service.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/services/payment_source_service.dart';

/// Onboarding state; ingest credentials persist locally and sync to Firestore.
class OnboardingState extends ChangeNotifier {
  OnboardingState({
    Uuid? uuid,
    DeviceTokenService? deviceTokenService,
    DeviceCredentialsStore? credentialsStore,
  })  : _uuid = uuid ?? const Uuid(),
        _deviceTokenService = deviceTokenService ?? DeviceTokenService(),
        _credentialsStore = credentialsStore ?? DeviceCredentialsStore();

  final Uuid _uuid;
  final DeviceTokenService _deviceTokenService;
  final DeviceCredentialsStore _credentialsStore;

  String email = '';
  String password = '';
  bool isAuthenticated = false;

  String deviceId = '';
  String ingestToken = '';
  String ingestUrl = 'https://ingestsms-ajirc5tjmq-el.a.run.app';

  final List<PaymentSource> paymentSources = [];

  bool shortcutsChecklistComplete = false;
  bool healthCheckPassed = false;
  bool healthCheckSkipped = false;
  bool deviceTokenSynced = false;
  String? deviceTokenSyncError;

  bool get paymentSourcesComplete =>
      paymentSources.any(
        (s) =>
            s.type == PaymentSourceType.bank ||
            s.type == PaymentSourceType.card,
      );

  bool get shortcutsGateSatisfied => healthCheckPassed || healthCheckSkipped;

  bool get onboardingComplete =>
      isAuthenticated && paymentSourcesComplete && shortcutsGateSatisfied;

  void setCredentials({required String email, required String password}) {
    this.email = email.trim();
    this.password = password;
    notifyListeners();
  }

  /// After Firebase Auth succeeds.
  Future<void> markAuthenticated({required String uid}) async {
    isAuthenticated = true;
    await ensureIngestDeviceRegistered(uid: uid);
  }

  /// Loads payment sources from Firestore into local state.
  Future<void> loadPaymentSources(PaymentSourceService service) async {
    final loaded = await service.loadAll();
    paymentSources
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Persists current payment sources to Firestore.
  Future<void> persistPaymentSources(PaymentSourceService service) async {
    await service.saveAll(paymentSources);
  }

  /// Loads or creates device credentials, persists locally, writes Firestore hash.
  Future<void> ensureIngestDeviceRegistered({required String uid}) async {
    deviceTokenSynced = false;
    deviceTokenSyncError = null;
    notifyListeners();

    try {
      final stored = await _credentialsStore.load(uid);
      if (stored != null) {
        deviceId = stored.deviceId;
        ingestToken = stored.token;
      } else {
        deviceId = _uuid.v4();
        ingestToken = _deviceTokenService.generateToken();
        await _credentialsStore.save(
          uid: uid,
          deviceId: deviceId,
          token: ingestToken,
        );
      }

      await _deviceTokenService.registerDeviceToken(
        uid: uid,
        deviceId: deviceId,
        rawToken: ingestToken,
      );
      deviceTokenSynced = true;
    } catch (e) {
      deviceTokenSyncError = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void setIngestUrl(String url) {
    ingestUrl = url.trim();
    notifyListeners();
  }

  void addPaymentSource(PaymentSource source) {
    if (source.type == PaymentSourceType.wallet) return;
    paymentSources.add(source);
    notifyListeners();
  }

  void updatePaymentSource(int index, PaymentSource source) {
    if (index < 0 || index >= paymentSources.length) return;
    if (source.type == PaymentSourceType.wallet) return;
    paymentSources[index] = source;
    notifyListeners();
  }

  void removePaymentSource(int index) {
    if (index < 0 || index >= paymentSources.length) return;
    paymentSources.removeAt(index);
    notifyListeners();
  }

  void setPaymentSources(List<PaymentSource> sources) {
    paymentSources
      ..clear()
      ..addAll(
        sources.where((s) => s.type != PaymentSourceType.wallet),
      );
    notifyListeners();
  }

  void markChecklistComplete(bool value) {
    shortcutsChecklistComplete = value;
    notifyListeners();
  }

  void confirmHealthCheckManual() {
    healthCheckPassed = true;
    healthCheckSkipped = false;
    notifyListeners();
  }

  void skipHealthCheck() {
    healthCheckSkipped = true;
    healthCheckPassed = false;
    notifyListeners();
  }
}
