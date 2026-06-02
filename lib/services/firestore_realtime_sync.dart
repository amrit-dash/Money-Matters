import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/auth_service.dart';
import '../ingest/ingest_repository.dart';
import 'category_service.dart';
import 'payment_source_service.dart';

/// Keeps SQLite and in-memory caches in sync with Firestore snapshot listeners.
///
/// UI reads SQLite via repositories; this service writes remote changes locally
/// so LLM background classification and multi-device edits appear instantly.
class FirestoreRealtimeSyncService {
  FirestoreRealtimeSyncService({
    required AuthService authService,
    required IngestRepository ingestRepository,
    required CategoryService categoryService,
    required PaymentSourceService paymentSourceService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _ingestRepository = ingestRepository,
        _categoryService = categoryService,
        _paymentSourceService = paymentSourceService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final IngestRepository _ingestRepository;
  final CategoryService _categoryService;
  final PaymentSourceService _paymentSourceService;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _transactionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sourcesSub;

  /// Starts listening to auth state and attaches Firestore listeners when signed in.
  void start() {
    _authSubscription ??= _authService.authStateChanges.listen((user) {
      _stopFirestoreListeners();
      if (user != null) {
        _startFirestoreListeners();
      }
    });

    if (_authService.isSignedIn) {
      _startFirestoreListeners();
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _stopFirestoreListeners();
  }

  void _startFirestoreListeners() {
    if (!_authService.isSignedIn) return;
    if (_transactionsSub != null) return;

    final uid = _authService.requireUid();
    final userRef = _firestore.collection('users').doc(uid);

    _transactionsSub = userRef
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          await _ingestRepository.mirrorTransactionDocChanges(snapshot);
        } catch (e, st) {
          debugPrint('FirestoreRealtimeSync.transactions: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('FirestoreRealtimeSync.transactions stream: $e\n$st');
      },
    );

    _categoriesSub = userRef.collection('categories').snapshots().listen(
      (snapshot) {
        try {
          _categoryService.applyRemoteSnapshot(snapshot);
        } catch (e, st) {
          debugPrint('FirestoreRealtimeSync.categories: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('FirestoreRealtimeSync.categories stream: $e\n$st');
      },
    );

    _sourcesSub = userRef
        .collection('payment_sources')
        .orderBy('createdAt')
        .snapshots()
        .listen(
      (snapshot) {
        try {
          _paymentSourceService.applyRemoteSnapshot(snapshot);
        } catch (e, st) {
          debugPrint('FirestoreRealtimeSync.payment_sources: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('FirestoreRealtimeSync.payment_sources stream: $e\n$st');
      },
    );
  }

  void _stopFirestoreListeners() {
    _transactionsSub?.cancel();
    _transactionsSub = null;
    _categoriesSub?.cancel();
    _categoriesSub = null;
    _sourcesSub?.cancel();
    _sourcesSub = null;
  }
}
