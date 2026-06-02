import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/auth_service.dart';
import '../core/db/local_data_streams.dart';
import '../models/payment_source.dart';

/// Persists payment sources to Firestore under users/{uid}/payment_sources.
class PaymentSourceService {
  PaymentSourceService({
    required AuthService authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final FirebaseFirestore _firestore;

  List<PaymentSource>? _cache;
  final StreamController<void> _sourceChanges =
      StreamController<void>.broadcast();

  /// Fires when payment sources are updated from Firestore snapshots.
  Stream<void> get paymentSourceChanges => _sourceChanges.stream;

  CollectionReference<Map<String, dynamic>> _collection() {
    final uid = _authService.requireUid();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payment_sources');
  }

  /// Re-emits whenever payment sources change locally or from Firestore snapshots.
  Stream<List<PaymentSource>> watchAll() {
    return watchLocalData(paymentSourceChanges, loadAll);
  }

  Future<List<PaymentSource>> loadAll() async {
    if (_cache != null) return _cache!;
    final uid = _requireSignedInUid();
    final snapshot =
        await _collection().orderBy('createdAt').get();
    final sources = snapshot.docs.map(_fromDoc).toList();
    _cache = sources;
    debugPrint(
      'PaymentSourceService.loadAll: uid=$uid count=${sources.length}',
    );
    return sources;
  }

  /// Updates the in-memory cache from a Firestore payment_sources snapshot.
  void applyRemoteSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _cache = snapshot.docs.map(_fromDoc).toList();
    if (!_sourceChanges.isClosed) {
      _sourceChanges.add(null);
    }
  }

  void invalidateCache() => _cache = null;

  Future<void> saveAll(List<PaymentSource> sources) async {
    final uid = _requireSignedInUid();
    final col = _collection();
    final existing = await col.get();
    final nextIds = sources.map((s) => s.id).toSet();

    final batch = _firestore.batch();
    var ops = 0;

    for (final doc in existing.docs) {
      if (!nextIds.contains(doc.id)) {
        batch.delete(doc.reference);
        ops++;
      }
    }
    for (final source in sources) {
      batch.set(col.doc(source.id), _toFirestore(source));
      ops++;
    }

    if (ops == 0) {
      debugPrint('PaymentSourceService.saveAll: uid=$uid nothing to write');
      return;
    }

    await batch.commit();
    _cache = List<PaymentSource>.from(sources);
    if (!_sourceChanges.isClosed) {
      _sourceChanges.add(null);
    }
    debugPrint(
      'PaymentSourceService.saveAll: uid=$uid wrote=${sources.length} ops=$ops',
    );
  }

  String _requireSignedInUid() {
    if (!_authService.isSignedIn) {
      throw StateError(
        'PaymentSourceService: sign in required to sync payment sources',
      );
    }
    return _authService.requireUid();
  }

  PaymentSource _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return PaymentSource(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: PaymentSourceType.fromString(data['type'] as String? ?? 'bank'),
      last4: data['last4'] as String?,
      senderHints: (data['senderHints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      merchantHints: (data['merchantHints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bodyPatterns: (data['bodyPatterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> _toFirestore(PaymentSource source) {
    return {
      'id': source.id,
      'name': source.name,
      'type': source.type.name,
      if (source.last4 != null) 'last4': source.last4,
      'senderHints': source.senderHints,
      'merchantHints': source.merchantHints,
      'bodyPatterns': source.bodyPatterns,
      'createdAt': Timestamp.fromDate(source.createdAt),
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Persists user-learned SMS patterns after manual payment-source assignment.
  Future<void> learnFromTransaction({
    required String paymentSourceId,
    required String sender,
    required String body,
    String? merchant,
    String? instrumentLast4,
  }) async {
    final col = _collection();
    final doc = await col.doc(paymentSourceId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final updates = <String, dynamic>{};

    final senderHint = _normalizeSenderHint(sender);
    if (senderHint != null) {
      updates['senderHints'] = FieldValue.arrayUnion([senderHint]);
    }

    final merchantHint = merchant?.trim().toUpperCase();
    if (merchantHint != null && merchantHint.isNotEmpty) {
      updates['merchantHints'] = FieldValue.arrayUnion([merchantHint]);
    }

    final bodyPattern = _extractBodyPattern(body, sender);
    if (bodyPattern != null) {
      updates['bodyPatterns'] = FieldValue.arrayUnion([bodyPattern]);
    }

    final last4 = normalizeLast4(instrumentLast4);
    final existingLast4 = data['last4'] as String?;
    if (last4.length == 4 &&
        (existingLast4 == null || existingLast4.isEmpty)) {
      updates['last4'] = last4;
    }

    if (updates.isEmpty) return;

    try {
      await col.doc(paymentSourceId).set(updates, SetOptions(merge: true));
      debugPrint(
        'PaymentSourceService.learnFromTransaction: updated $paymentSourceId',
      );
    } catch (e) {
      debugPrint('PaymentSourceService.learnFromTransaction: $e');
    }
  }

  String? _normalizeSenderHint(String sender) {
    final trimmed = sender.trim();
    if (trimmed.length < 4) return null;
    return trimmed.toUpperCase();
  }

  /// Picks a short distinctive substring from the SMS body for rematching.
  String? _extractBodyPattern(String body, String sender) {
    final normalized = body.trim();
    if (normalized.length < 8) return null;

    final senderHint = _normalizeSenderHint(sender);
    if (senderHint != null &&
        normalized.toUpperCase().contains(senderHint)) {
      return senderHint;
    }

    final lines = normalized.split(RegExp(r'[\r\n]+'));
    for (final line in lines.reversed) {
      final trimmed = line.trim();
      if (trimmed.length >= 8 && trimmed.length <= 48) {
        return trimmed;
      }
    }
    return null;
  }
}
