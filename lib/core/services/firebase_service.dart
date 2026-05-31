import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Auth methods
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> loginWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // Firestore methods
  static Future<void> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collection).add(data);
  }

  static Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collection).doc(docId).set(data);
  }

  static Future<DocumentSnapshot> getDocument(
    String collection,
    String docId,
  ) async {
    return await _firestore.collection(collection).doc(docId).get();
  }

  static Future<QuerySnapshot> getCollectionWhere(
    String collection,
    String field,
    dynamic isEqualTo,
  ) async {
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
    await _firestore.collection(collection).doc(docId).update(data);
  }

  static Future<void> deleteDocument(
    String collection,
    String docId,
  ) async {
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
