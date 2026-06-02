import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/auth/auth_service.dart';
import '../models/llm_log_entry.dart';

/// Reads `users/{uid}/llm_logs` written by Cloud Functions.
class LlmLogsService {
  LlmLogsService({
    required AuthService authService,
    FirebaseFirestore? firestore,
  })  : _auth = authService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _auth;
  final FirebaseFirestore _firestore;

  static const maxEntries = 100;

  CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = _auth.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('llm_logs');
  }

  Stream<List<LlmLogEntry>> watchRecent({int limit = 50}) {
    final col = _collection();
    if (col == null) return Stream.value(const []);

    return col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(LlmLogEntry.fromDoc).toList(),
        );
  }

  Future<void> clearAll() async {
    final col = _collection();
    if (col == null) return;

    while (true) {
      final snap = await col.limit(450).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
