import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import 'parse_result.dart';

/// Rules-first parser for Indian bank / wallet SMS templates.
class RulesParser {
  const RulesParser({this.rulesVersion = '1.0.0'});

  final String rulesVersion;

  static final RegExp _amountPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _last4Pattern = RegExp(
    r'\*\*(\d{4})|'
    r'(?:ending|ends)\s+(?:with\s+)?(?:\*{1,2}|X{1,4})*(\d{4})|'
    r'(?:A[/\\]c|Acct|Account)\.?\s*(?:no\.?\s*)?(?:\*{1,2}|X{1,4})*(\d{4})|'
    r'(?:Card|card)\s+(?:no\.?\s*)?(?:\*{1,2}|X{1,4})*(\d{4})|'
    r'Acct\s+XX(\d{3,4})|'
    r'(?:wallet)\s+(?:XX)?(\d{4})',
    caseSensitive: false,
  );

  static final RegExp _merchantAtPattern = RegExp(
    r'\bat\s+([A-Z0-9][A-Z0-9\s&\-.]{1,40}?)\s+on\b',
    caseSensitive: false,
  );

  static final RegExp _merchantColonPattern = RegExp(
    r'Merchant:\s*([A-Za-z0-9][A-Za-z0-9\s&\-.]{1,40}?)(?:\.|;|\s+Avl|\s*$)',
    caseSensitive: false,
  );

  static final RegExp _upiPathMerchantPattern = RegExp(
    r'UPI/([^/]+)/',
    caseSensitive: false,
  );

  /// Federal Bank: Rs 10.00 sent via UPI on 31-05-2026 at 02:50:52 to vpa@.
  static final RegExp _federalSentUpiPattern = RegExp(
    r'sent via UPI on .+? to ([\w.\-]+@[\w.\-]*?)(?=[\s,.]|$)',
    caseSensitive: false,
  );

  static final RegExp _upiToVpaPattern = RegExp(
    r'\bto\s+([\w.\-]+@[\w.\-]*?)(?=[\s,.]|$)',
    caseSensitive: false,
  );

  static final RegExp _upiPattern = RegExp(
    r'(?:paid|sent)\s+(?:to\s+)?(?!via\b)([A-Z][A-Z\s]{2,30})(?:\s+via|\s+on|\s+using|\s*$)',
    caseSensitive: false,
  );

  static final RegExp _timePattern = RegExp(
    r'\bat\s+(\d{2}:\d{2}(?::\d{2})?)\b',
  );

  static final RegExp _datePattern = RegExp(
    r'(\d{1,2}[-/](?:\d{1,2}|[A-Za-z]{3})[-/]\d{2,4})',
  );

  static final List<RegExp> _reminderPatterns = [
    RegExp(r'bill\s+due', caseSensitive: false),
    RegExp(r'payment\s+due', caseSensitive: false),
    RegExp(r'minimum\s+due', caseSensitive: false),
    RegExp(r'\bmin\.?\s+due', caseSensitive: false),
    RegExp(r'due\s+on', caseSensitive: false),
    RegExp(r'statement\s+generated', caseSensitive: false),
    RegExp(r'pay\s+by', caseSensitive: false),
    RegExp(r'emi\s+due', caseSensitive: false),
    RegExp(r'total\s+amount\s+due', caseSensitive: false),
  ];

  /// Marketing / loan-offer markers that reject a message even when it also
  /// contains a debit/credit verb (e.g. "...get Rs.6,00,130 credited! Apply now").
  /// A genuine bank debit/credit alert never contains these.
  static final List<RegExp> _hardPromoPatterns = [
    RegExp(r'pre[\s-]?approved', caseSensitive: false),
    RegExp(r'\bapply\s+now\b', caseSensitive: false),
    RegExp(r'eligible\s+for', caseSensitive: false),
    RegExp(r'you\s+are\s+eligible', caseSensitive: false),
    RegExp(r'loan\s+offer', caseSensitive: false),
    RegExp(r'personal\s+loan', caseSensitive: false),
    RegExp(r'instant\s+loan', caseSensitive: false),
    RegExp(r'business\s+loan', caseSensitive: false),
    RegExp(r'\bloan\s+up\s*to\b', caseSensitive: false),
    RegExp(r'\bget\s+a\s+loan\b', caseSensitive: false),
    RegExp(r'emi\s+offer', caseSensitive: false),
    RegExp(r'limited\s+time', caseSensitive: false),
    RegExp(r'lowest\s+interest', caseSensitive: false),
    RegExp(r'interest\s+rate', caseSensitive: false),
    RegExp(r'click\s+here', caseSensitive: false),
    RegExp(r't&c\s*apply', caseSensitive: false),
    RegExp(r'\bredeem\b', caseSensitive: false),
    RegExp(r'reward\s+points', caseSensitive: false),
    RegExp(r'cashback\s+offer', caseSensitive: false),
    RegExp(r'download\s+(?:our\s+)?app', caseSensitive: false),
    RegExp(r'\bcongratulations\b', caseSensitive: false),
    RegExp(r'missed\s+call', caseSensitive: false),
    RegExp(r'offer\s+valid', caseSensitive: false),
    RegExp(r'\bhurry\b', caseSensitive: false),
  ];

  /// Softer promo markers — only reject when there is no real debit/credit verb.
  static final List<RegExp> _promoPatterns = [
    RegExp(r'\boffer\b', caseSensitive: false),
    RegExp(r'\bdiscount\b', caseSensitive: false),
    RegExp(r'\bsale\b', caseSensitive: false),
    RegExp(r'\bwin\b', caseSensitive: false),
  ];

  /// Account / card / UPI context — a genuine transaction references one.
  static final RegExp _instrumentContextPattern = RegExp(
    r'\bA/c\b|\bAcct?\b|\baccount\b|\bcard\b|\bUPI\b|\bwallet\b|\bVPA\b|'
    r'\*\*\d|ending\s+\d|\bx{2,}\d',
    caseSensitive: false,
  );

  static final List<RegExp> _debitPatterns = [
    RegExp(r'\bdebited\b', caseSensitive: false),
    RegExp(r'\bspent\b', caseSensitive: false),
    RegExp(r'\bpaid\b', caseSensitive: false),
    RegExp(r'\bsent\b', caseSensitive: false),
    RegExp(r'\bwithdrawn\b', caseSensitive: false),
    RegExp(r'\bpurchase\b', caseSensitive: false),
    // Federal/Scapia card: "txn of Rs 61.83 at MERCHANT on your ... credit card".
    RegExp(r'\btxn\s+of\b', caseSensitive: false),
    // Card-spend alerts: "Thank you for using ... Card ending 1234 for Rs ...".
    RegExp(r'using\b[\w\s]*\bcard\b', caseSensitive: false),
    RegExp(r'\bdr\b', caseSensitive: false),
  ];

  static final List<RegExp> _creditPatterns = [
    RegExp(r'\bcredited\b', caseSensitive: false),
    RegExp(r'\breceived\b', caseSensitive: false),
    RegExp(r'\brefund\b', caseSensitive: false),
    RegExp(r'\bcr\b', caseSensitive: false),
  ];

  /// Last-4 account/card digits from SMS body (no transaction classification).
  String? extractInstrumentLast4(String body) => _extractLast4(body);

  ParseResult parse(RawIngest ingest) {
    final body = ingest.body.trim();
    if (body.isEmpty) {
      return ParseResult(
        classification: IngestClassification.unknown,
        confidence: 0,
        rulesVersion: rulesVersion,
      );
    }

    // Hard promo / loan-offer markers reject even with a debit/credit verb.
    // This is the primary guard against false positives such as a loan-offer
    // SMS being logged as a large transaction.
    if (_matchesAny(body, _hardPromoPatterns)) {
      return ParseResult(
        classification: IngestClassification.promo,
        confidence: 0.9,
        rulesVersion: rulesVersion,
      );
    }

    if (_matchesAny(body, _promoPatterns) && !_hasStrongTransactionSignal(body)) {
      return ParseResult(
        classification: IngestClassification.promo,
        confidence: 0.85,
        rulesVersion: rulesVersion,
      );
    }

    if (_matchesAny(body, _reminderPatterns) && !_hasStrongTransactionSignal(body)) {
      return ParseResult(
        classification: IngestClassification.billingReminder,
        confidence: 0.9,
        rulesVersion: rulesVersion,
      );
    }

    // A real transaction requires an explicit debit/credit verb — a bare amount
    // (e.g. "Avl bal Rs.5,000") or balance enquiry must not create a row.
    if (!_hasStrongTransactionSignal(body)) {
      return ParseResult(
        classification: IngestClassification.unknown,
        confidence: 0.2,
        rulesVersion: rulesVersion,
      );
    }

    final amount = _extractAmount(body);
    if (amount == null) {
      return ParseResult(
        classification: IngestClassification.unknown,
        confidence: 0.3,
        rulesVersion: rulesVersion,
      );
    }

    // Require account/card/UPI context: a genuine debit/credit alert references
    // the instrument. Without it the detection is too weak to count as spend.
    if (!_instrumentContextPattern.hasMatch(body)) {
      return ParseResult(
        classification: IngestClassification.unknown,
        confidence: 0.35,
        rulesVersion: rulesVersion,
      );
    }

    final type = _extractType(body);
    final merchant = _extractMerchant(body);
    final last4 = _extractLast4(body);
    final upiHint = _extractUpiHint(body);
    final timestamp = _extractTimestamp(body, ingest.receivedAt);
    final ambiguous = _isAmbiguous(merchant, upiHint);

    return ParseResult(
      classification: IngestClassification.transaction,
      candidate: ParsedTransactionCandidate(
        amount: amount,
        type: type,
        merchant: merchant,
        timestamp: timestamp,
        instrumentLast4: last4,
        upiHint: upiHint,
        ambiguous: ambiguous,
      ),
      confidence: ambiguous ? 0.65 : 0.92,
      rulesVersion: rulesVersion,
    );
  }

  bool _matchesAny(String body, List<RegExp> patterns) {
    return patterns.any((p) => p.hasMatch(body));
  }

  bool _hasStrongTransactionSignal(String body) {
    return _matchesAny(body, _debitPatterns) ||
        _matchesAny(body, _creditPatterns);
  }

  double? _extractAmount(String body) {
    final match = _amountPattern.firstMatch(body);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  TransactionType _extractType(String body) {
    final hasCredit = _matchesAny(body, _creditPatterns);
    final hasDebit = _matchesAny(body, _debitPatterns);
    if (hasCredit && !hasDebit) return TransactionType.credit;
    return TransactionType.debit;
  }

  String? _extractLast4(String body) {
    final match = _last4Pattern.firstMatch(body);
    if (match == null) return null;
    for (var i = 1; i <= match.groupCount; i++) {
      final group = match.group(i);
      if (group != null && group.isNotEmpty) {
        return group.length == 3 ? group.padLeft(4, '0') : group;
      }
    }
    return null;
  }

  String? _extractMerchant(String body) {
    final federalMatch = _federalSentUpiPattern.firstMatch(body);
    if (federalMatch != null) {
      return _cleanVpaMerchant(federalMatch.group(1)!);
    }

    final atMatch = _merchantAtPattern.firstMatch(body);
    if (atMatch != null) {
      return _cleanMerchant(atMatch.group(1)!);
    }

    final colonMatch = _merchantColonPattern.firstMatch(body);
    if (colonMatch != null) {
      return _cleanMerchant(colonMatch.group(1)!);
    }

    final upiPathMatch = _upiPathMerchantPattern.firstMatch(body);
    if (upiPathMatch != null) {
      return _cleanMerchant(upiPathMatch.group(1)!);
    }

    final vpaMatch = _upiToVpaPattern.firstMatch(body);
    if (vpaMatch != null) {
      return _cleanVpaMerchant(vpaMatch.group(1)!);
    }

    final upiMatch = _upiPattern.firstMatch(body);
    if (upiMatch != null) {
      return _cleanMerchant(upiMatch.group(1)!);
    }

    return null;
  }

  String? _extractUpiHint(String body) {
    if (!RegExp(r'\bUPI\b', caseSensitive: false).hasMatch(body)) {
      return null;
    }

    final federalMatch = _federalSentUpiPattern.firstMatch(body);
    if (federalMatch != null) {
      return _normalizeVpa(federalMatch.group(1)!);
    }

    final toVpaMatch = _upiToVpaPattern.firstMatch(body);
    if (toVpaMatch != null) {
      return _normalizeVpa(toVpaMatch.group(1)!);
    }

    final vpaMatch = RegExp(
      r'([\w.\-]+@[\w.\-]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (vpaMatch != null) return _normalizeVpa(vpaMatch.group(1)!);

    final upiPath = RegExp(
      r'UPI/[^/]+/([\w.@]+)',
      caseSensitive: false,
    ).firstMatch(body);
    return upiPath?.group(1);
  }

  String _cleanMerchant(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  String _cleanVpaMerchant(String raw) {
    return _normalizeVpa(raw).toUpperCase();
  }

  String _normalizeVpa(String raw) {
    var vpa = raw.trim();
    if (vpa.endsWith('.')) {
      vpa = vpa.substring(0, vpa.length - 1);
    }
    return vpa;
  }

  DateTime _extractTimestamp(String body, DateTime fallback) {
    final match = _datePattern.firstMatch(body);
    if (match == null) return fallback;

    final token = match.group(1)!;
    final parts = token.split(RegExp(r'[-/]'));
    if (parts.length != 3) return fallback;

    try {
      final day = int.parse(parts[0]);
      final month = _parseMonth(parts[1]);
      var year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      var hour = fallback.hour;
      var minute = fallback.minute;
      var second = 0;
      final timeMatch = _timePattern.firstMatch(body);
      if (timeMatch != null) {
        final timeParts = timeMatch.group(1)!.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        if (timeParts.length > 2) {
          second = int.parse(timeParts[2]);
        }
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return fallback;
    }
  }

  int _parseMonth(String token) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final lower = token.toLowerCase();
    if (months.containsKey(lower)) return months[lower]!;
    return int.parse(token);
  }

  bool _isAmbiguous(String? merchant, String? upiHint) {
    if (merchant == null || merchant.isEmpty) return true;

    final knownBrands = {
      'SWIGGY',
      'ZOMATO',
      'ZUDIO',
      'AMAZON',
      'FLIPKART',
      'BIGBASKET',
      'ZEPTO',
      'BLINKIT',
    };
    if (knownBrands.contains(merchant)) return false;

    // Person-name or personal VPA UPI payments (AE8 / Federal Bank).
    if (upiHint != null || merchant.contains(' ') || merchant.contains('@')) {
      final looksLikePerson = RegExp(r'^[A-Z]+(?: [A-Z]+)?$').hasMatch(merchant);
      if (looksLikePerson && merchant.split(' ').length <= 3) {
        return true;
      }
      if (merchant.contains('@')) return true;
    }

    return false;
  }
}
