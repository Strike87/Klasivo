import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'performance_trace_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Whether to wrap Firestore operations in performance traces.
  /// Enabled automatically when PerformanceTraceService is initialized.
  static bool get _tracingEnabled => PerformanceTraceService.instance.isEnabled;

  // Auth methods
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceAuth(
        'register',
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );
    }
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> loginWithEmail(
    String email,
    String password,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceAuth(
        'login',
        () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );
    }
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> logout() async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceAuth(
        'logout',
        () => _auth.signOut(),
      );
    }
    await _auth.signOut();
  }

  // Firestore methods — with performance tracing
  static Future<void> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreWrite(
        collection,
        'add',
        () => _firestore.collection(collection).add(data),
      );
    }
    await _firestore.collection(collection).add(data);
  }

  static Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreWrite(
        collection,
        'set',
        () => _firestore.collection(collection).doc(docId).set(data),
        docId: docId,
      );
    }
    await _firestore.collection(collection).doc(docId).set(data);
  }

  static Future<DocumentSnapshot> getDocument(
    String collection,
    String docId,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreRead(
        collection,
        'get',
        () => _firestore.collection(collection).doc(docId).get(),
        docId: docId,
      );
    }
    return await _firestore.collection(collection).doc(docId).get();
  }

  static Future<QuerySnapshot> getCollectionWhere(
    String collection,
    String field,
    dynamic isEqualTo,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreRead(
        collection,
        'query_where',
        () => _firestore
            .collection(collection)
            .where(field, isEqualTo: isEqualTo)
            .get(),
        extraAttributes: {'query_field': field},
      );
    }
    return await _firestore
        .collection(collection)
        .where(field, isEqualTo: isEqualTo)
        .get();
  }

  static Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreWrite(
        collection,
        'update',
        () => _firestore.collection(collection).doc(docId).update(data),
        docId: docId,
      );
    }
    await _firestore.collection(collection).doc(docId).update(data);
  }

  static Future<void> deleteDocument(
    String collection,
    String docId,
  ) async {
    if (_tracingEnabled) {
      return PerformanceTraceService.instance.traceFirestoreWrite(
        collection,
        'delete',
        () => _firestore.collection(collection).doc(docId).delete(),
        docId: docId,
      );
    }
    await _firestore.collection(collection).doc(docId).delete();
  }

  // Messaging
  static Future<String?> getDeviceToken() async {
    return await _messaging.getToken();
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
