import 'package:shared_preferences/shared_preferences.dart';

import '../../models/payment_source.dart';
import '../../services/payment_source_service.dart';

/// Persists per-user onboarding completion locally.
class OnboardingProgressStore {
  OnboardingProgressStore({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;

  static String _key(String uid) => 'onboarding_complete_$uid';

  Future<bool> isComplete(String uid) async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_key(uid)) ?? false;
  }

  Future<void> markComplete(String uid) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_key(uid), true);
  }

  Future<void> clear(String uid) async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_key(uid));
  }

  /// Existing installs: skip onboarding when accounts or ledger data already exist.
  Future<bool> shouldShowOnboarding({
    required String uid,
    required PaymentSourceService paymentSourceService,
    Future<int> Function()? transactionCount,
  }) async {
    if (await isComplete(uid)) return false;

    final sources = await paymentSourceService.loadAll();
    final hasAccount = sources.any(
      (s) =>
          s.type == PaymentSourceType.bank ||
          s.type == PaymentSourceType.card,
    );
    if (hasAccount) {
      await markComplete(uid);
      return false;
    }

    if (transactionCount != null) {
      final count = await transactionCount();
      if (count > 0) {
        await markComplete(uid);
        return false;
      }
    }

    return true;
  }
}
