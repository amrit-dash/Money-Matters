import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/auth_service.dart';
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

  CollectionReference<Map<String, dynamic>> _collection() {
    final uid = _authService.requireUid();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payment_sources');
  }

  Future<List<PaymentSource>> loadAll() async {
    final uid = _requireSignedInUid();
    final snapshot =
        await _collection().orderBy('createdAt').get();
    final sources = snapshot.docs.map(_fromDoc).toList();
    debugPrint(
      'PaymentSourceService.loadAll: uid=$uid count=${sources.length}',
    );
    return sources;
  }

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
}
