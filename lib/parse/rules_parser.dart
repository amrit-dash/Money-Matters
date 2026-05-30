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
    r'\*\*(\d{4})|(?:ending|ends)\s+(?:XX)?(\d{4})|A/c\s+(?:XX)?(\d{4})|'
    r'Acct\s+XX(\d{3,4})|Card\s+(?:XX)?(\d{4})',
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
    RegExp(r'due\s+on', caseSensitive: false),
    RegExp(r'statement\s+generated', caseSensitive: false),
    RegExp(r'pay\s+by', caseSensitive: false),
  ];

  static final List<RegExp> _promoPatterns = [
    RegExp(r'pre[\s-]?approved', caseSensitive: false),
    RegExp(r'limited\s+time\s+offer', caseSensitive: false),
    RegExp(r'cashback\s+offer', caseSensitive: false),
    RegExp(r'reward\s+points', caseSensitive: false),
    RegExp(r'congratulations', caseSensitive: false),
    RegExp(r'download\s+(?:our\s+)?app', caseSensitive: false),
    RegExp(r'apply\s+now', caseSensitive: false),
    RegExp(r'loan\s+offer', caseSensitive: false),
  ];

  static final List<RegExp> _debitPatterns = [
    RegExp(r'\bdebited\b', caseSensitive: false),
    RegExp(r'\bspent\b', caseSensitive: false),
    RegExp(r'\bpaid\b', caseSensitive: false),
    RegExp(r'\bsent\b', caseSensitive: false),
    RegExp(r'\bwithdrawn\b', caseSensitive: false),
    RegExp(r'\bdr\b', caseSensitive: false),
  ];

  static final List<RegExp> _creditPatterns = [
    RegExp(r'\bcredited\b', caseSensitive: false),
    RegExp(r'\breceived\b', caseSensitive: false),
    RegExp(r'\brefund\b', caseSensitive: false),
    RegExp(r'\bcr\b', caseSensitive: false),
  ];

  ParseResult parse(RawIngest ingest) {
    final body = ingest.body.trim();
    if (body.isEmpty) {
      return ParseResult(
        classification: IngestClassification.unknown,
        confidence: 0,
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

    if (!_looksLikeTransaction(body)) {
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

  bool _looksLikeTransaction(String body) {
    return _matchesAny(body, _debitPatterns) ||
        _matchesAny(body, _creditPatterns) ||
        _amountPattern.hasMatch(body);
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
