import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import 'category_service.dart';

/// Deletes all ledger data for the signed-in user (local SQLite + Firestore).
///
/// Preserves the Firebase Auth account — sign out is a separate action.
class UserDataDeletionService {
  UserDataDeletionService({
    required AuthService authService,
    required LocalDatabase localDatabase,
    required CategoryService categoryService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _localDatabase = localDatabase,
        _categoryService = categoryService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final LocalDatabase _localDatabase;
  final CategoryService _categoryService;
  final FirebaseFirestore _firestore;

  /// Firestore subcollections under `users/{uid}/` that hold user ledger data.
  static const userSubcollectionNames = [
    'transactions',
    'raw_ingests',
    'parse_jobs',
    'payment_sources',
    'categories',
    'device_tokens',
    'fcm_tokens',
    'llm_logs',
    'settings',
  ];

  /// Clears local SQLite and all Firestore subcollections for [uid].
  ///
  /// Throws [StateError] when no user is signed in.
  Future<UserDataDeletionResult> deleteAllUserData() async {
    final uid = _authService.requireUid();

    await _localDatabase.clearAllUserData();
    _categoryService.invalidateCache();

    var firestoreDocsDeleted = 0;
    for (final name in userSubcollectionNames) {
      final col = _firestore.collection('users').doc(uid).collection(name);
      firestoreDocsDeleted += await _deleteCollection(col);
    }

    debugPrint(
      'UserDataDeletionService: uid=$uid '
      'firestoreDocsDeleted=$firestoreDocsDeleted',
    );

    return UserDataDeletionResult(
      uid: uid,
      firestoreDocsDeleted: firestoreDocsDeleted,
    );
  }

  Future<int> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 450;
    var deleted = 0;

    while (true) {
      final snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snapshot.docs.length;
    }

    return deleted;
  }
}

class UserDataDeletionResult {
  const UserDataDeletionResult({
    required this.uid,
    required this.firestoreDocsDeleted,
  });

  final String uid;
  final int firestoreDocsDeleted;
}
