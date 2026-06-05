import 'dart:async';

import 'package:app_links/app_links.dart';

import 'ingest_queue_drain.dart';

/// Parsed payload from `moneymatters://ingest?...` deep link.
///
/// POST via Shortcuts remains the source of truth; URL ingest triggers a drain
/// for faster UI refresh when the app is foreground (R4).
class UrlIngestPayload {
  const UrlIngestPayload({
    required this.body,
    required this.sender,
    required this.receivedAt,
    this.source = 'url-scheme-v1',
  });

  final String body;
  final String sender;
  final DateTime receivedAt;
  final String source;

  /// iOS URL query length limits may truncate body; caller should treat as hint.
  bool get isBodyTruncated => body.length >= 1800;

  @override
  String toString() =>
      'UrlIngestPayload(sender=$sender, receivedAt=$receivedAt, bodyLen=${body.length})';
}

/// Handles `moneymatters://` deep links for ingest and recovery routes.
class UrlIngestHandler {
  UrlIngestHandler({
    required IngestQueueDrain queueDrain,
    AppLinks? appLinks,
  })  : _queueDrain = queueDrain,
        _appLinks = appLinks ?? AppLinks();

  final IngestQueueDrain _queueDrain;
  final AppLinks _appLinks;

  static const scheme = 'moneymatters';
  static const ingestHost = 'ingest';
  static const recoveryHost = 'recovery';
  static const classifyHost = 'classify';

  final StreamController<UrlIngestPayload> _ingestEvents =
      StreamController<UrlIngestPayload>.broadcast();

  final StreamController<Uri> _recoveryEvents =
      StreamController<Uri>.broadcast();

  final StreamController<String> _classifyEvents =
      StreamController<String>.broadcast();

  StreamSubscription<Uri>? _linkSubscription;

  /// Emits when an ingest URL is received (after triggering drain).
  Stream<UrlIngestPayload> get onIngestUrl => _ingestEvents.stream;

  /// Emits when `moneymatters://recovery` is opened (Shortcut B).
  Stream<Uri> get onRecoveryUrl => _recoveryEvents.stream;

  /// Emits transaction id from `moneymatters://classify?txId=...`.
  Stream<String> get onClassifyUrl => _classifyEvents.stream;

  /// Starts listening for initial and subsequent deep links.
  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handleUri(initial);
    }

    _linkSubscription ??= _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != scheme) return;

    switch (uri.host) {
      case ingestHost:
        final payload = parseIngestUri(uri);
        if (payload != null) {
          await _queueDrain.drainIfAuthenticated();
          _ingestEvents.add(payload);
        }
      case recoveryHost:
        _recoveryEvents.add(uri);
      case classifyHost:
        final txId = uri.queryParameters['txId'];
        if (txId != null && txId.isNotEmpty) {
          _classifyEvents.add(txId);
        }
      default:
        break;
    }
  }

  /// Parses `moneymatters://ingest?body=...&sender=...&receivedAt=...`.
  static UrlIngestPayload? parseIngestUri(Uri uri) {
    if (uri.scheme != scheme || uri.host != ingestHost) {
      return null;
    }

    final body = uri.queryParameters['body'];
    final sender = uri.queryParameters['sender'];
    final receivedAtRaw = uri.queryParameters['receivedAt'];

    if (body == null || body.isEmpty || sender == null || sender.isEmpty) {
      return null;
    }

    DateTime receivedAt;
    if (receivedAtRaw != null && receivedAtRaw.isNotEmpty) {
      receivedAt = DateTime.tryParse(receivedAtRaw)?.toUtc() ??
          DateTime.now().toUtc();
    } else {
      receivedAt = DateTime.now().toUtc();
    }

    return UrlIngestPayload(
      body: body,
      sender: sender,
      receivedAt: receivedAt,
      source: uri.queryParameters['source'] ?? 'url-scheme-v1',
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
    _ingestEvents.close();
    _recoveryEvents.close();
    _classifyEvents.close();
  }
}
