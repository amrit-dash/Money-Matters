import '../models/payment_source.dart';
import '../models/transaction.dart';
import '../services/llm_settings_service.dart';
import 'llm_parser.dart';

/// Skips Cloud Function classify when the user disabled LLM or has no API key.
class LlmAwareClassifier implements TransactionClassifier {
  LlmAwareClassifier({
    required TransactionClassifier delegate,
    required LlmSettingsService settingsService,
  })  : _delegate = delegate,
        _settingsService = settingsService;

  final TransactionClassifier _delegate;
  final LlmSettingsService _settingsService;

  @override
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    String? smsSender,
    List<String> categoryIds = const [],
    String? selectedCategoryId,
    String? userDescription,
    Map<String, List<String>> subcategoryTaxonomy = const {},
    List<PaymentSource> paymentSources = const [],
    bool includePaymentSources = true,
    bool includeSubcategoryTaxonomy = true,
  }) async {
    final settings = await _settingsService.load();
    if (settings.updatedAt != null) {
      if (!settings.enabled) {
        ClassifierDiagnostics.recordAttempt(
          error: 'LLM disabled in Agent settings',
        );
        return null;
      }
      if (!settings.isConfigured) {
        ClassifierDiagnostics.recordAttempt(
          needsConfig: true,
          error: 'Configure provider and API key in Agent settings',
        );
        return const ClassificationResult(needsConfig: true);
      }
    }

    return _delegate.classify(
      transaction: transaction,
      smsBody: smsBody,
      smsSender: smsSender,
      categoryIds: categoryIds,
      selectedCategoryId: selectedCategoryId,
      userDescription: userDescription,
      subcategoryTaxonomy: subcategoryTaxonomy,
      paymentSources: paymentSources,
      includePaymentSources: includePaymentSources,
      includeSubcategoryTaxonomy: includeSubcategoryTaxonomy,
    );
  }
}
