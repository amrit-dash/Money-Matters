import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (!_authService.isSignedIn) return [];
    final snapshot = await _collection().orderBy('createdAt').get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  Future<void> saveAll(List<PaymentSource> sources) async {
    if (!_authService.isSignedIn) return;
    final col = _collection();
    final batch = _firestore.batch();
    final existing = await col.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final source in sources) {
      batch.set(col.doc(source.id), _toFirestore(source));
    }
    await batch.commit();
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
