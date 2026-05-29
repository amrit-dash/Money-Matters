import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:money_matters/models/payment_source.dart';

/// In-memory onboarding state until coordinator wires Firebase + Keychain.
class OnboardingState extends ChangeNotifier {
  OnboardingState({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

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

  int get bankCount =>
      paymentSources.where((s) => s.type == PaymentSourceType.bank).length;

  int get cardCount =>
      paymentSources.where((s) => s.type == PaymentSourceType.card).length;

  bool get paymentSourcesComplete => bankCount >= 2 && cardCount >= 2;

  bool get shortcutsGateSatisfied => healthCheckPassed || healthCheckSkipped;

  bool get onboardingComplete =>
      isAuthenticated && paymentSourcesComplete && shortcutsGateSatisfied;

  void setCredentials({required String email, required String password}) {
    this.email = email.trim();
    this.password = password;
    notifyListeners();
  }

  void markAuthenticated() {
    isAuthenticated = true;
    deviceId = _uuid.v4();
    ingestToken = _generateStubToken();
    notifyListeners();
  }

  void setIngestUrl(String url) {
    ingestUrl = url.trim();
    notifyListeners();
  }

  void addPaymentSource(PaymentSource source) {
    paymentSources.add(source);
    notifyListeners();
  }

  void updatePaymentSource(int index, PaymentSource source) {
    if (index < 0 || index >= paymentSources.length) return;
    paymentSources[index] = source;
    notifyListeners();
  }

  void removePaymentSource(int index) {
    if (index < 0 || index >= paymentSources.length) return;
    paymentSources.removeAt(index);
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

  String _generateStubToken() {
    final bytes = List<int>.generate(32, (i) => (i * 17 + 91) % 256);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
