import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance.collection('users');

  Future<void> createUser(Users user) async {
    try {
      await _db.doc(user.userId).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<Users?> getUser(String uid) async {
    try {
      final doc = await _db.doc(uid).get();
      if (!doc.exists) return null;
      return Users.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<void> updateUser(Users user) async {
    try {
      await _db.doc(user.userId).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<Users?> getOrCreateUserOnLogin(User firebaseUser) async {
    try {
      Users? user = await getUser(firebaseUser.uid);
      
      if (user == null) {
        user = Users(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          contact: firebaseUser.phoneNumber ?? '',
          gender: 'Male',
          role: "Member",
          photoUrl: firebaseUser.photoURL ?? '',
          creationDateTime: DateTime.now(),
        );
        await createUser(user);
      } else {
        final updatedUser = user.copyWith(
          name: firebaseUser.displayName ?? user.name,
          email: firebaseUser.email ?? user.email,
          photoUrl: firebaseUser.photoURL ?? user.photoUrl,
        );
        await updateUser(updatedUser);
        user = updatedUser;
      }
      
      return user;
    } catch (e) {
      throw Exception('Failed to handle user login: $e');
    }
  }

  Future<Users?> getCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;
    return getUser(currentUser.uid);
  }

  Future<List<Users>> getAllUsers() async {
    try {
      final snapshot = await _db.get();
      return snapshot.docs.map((doc) => Users.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  Future<bool> userExists(String uid) async {
    final doc = await _db.doc(uid).get();
    return doc.exists;
  }

  Stream<Users?> streamUser(String uid) {
    return _db.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Users.fromMap(doc.data()!, doc.id);
    });
  }

  Stream<Users?> streamCurrentUser() {
    return FirebaseAuth.instance.authStateChanges().asyncMap((firebaseUser) {
      if (firebaseUser == null) return null;
      return streamUser(firebaseUser.uid).first;
    });
  }

  Future<List<Users>> getUsersPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _db.limit(limit);
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Users.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Stream<List<Users>> getAllUsersStream() {
    return _db.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Users.fromMap(doc.data(), doc.id)).toList();
    });
  }
}