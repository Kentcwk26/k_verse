import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../screens/adminstrators/adminstrator.dart';
import '../screens/home.dart';
import '../screens/login.dart';

class AuthViewModel with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  User? _currentUser;
  Users? _currentUserData;

  bool _shouldNavigate = false;
  Widget? _targetScreen;
  
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  User? get currentUser => _currentUser;
  Users? get currentUserData => _currentUserData;
  bool get shouldNavigate => _shouldNavigate;
  Widget? get targetScreen => _targetScreen;

  Future<Users?> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return Users.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<Widget> checkLoginStatus() async {
    _setLoading(true);

    try {
      final user = _authRepository.currentUser;

      if (user != null) {
        _currentUser = user;
        _currentUserData = await _getUserData(user.uid);

        _setLoading(false);
        return _getRouteBasedOnRole();
      } else {
        _setLoading(false);
        return LoginScreen();
      }
    } catch (e) {
      _setLoading(false);
      _setError('Error checking authentication status: $e');
      return LoginScreen();
    }
  }

  Widget _getRouteBasedOnRole() {
    if (_currentUserData == null) {
      print("❌ No user data available, defaulting to HomeScreen");
      return HomeScreen();
    }

    print("🎯 Determining route for role: ${_currentUserData!.role}");
    
    switch (_currentUserData!.role.toLowerCase()) {
      case 'admin':
        return AdminstratorScreen();
      case 'member':
        return HomeScreen();
      default:
        print("⚠️ Unknown role: ${_currentUserData!.role}, defaulting to HomeScreen");
        return HomeScreen();
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError('');
    _setSuccess('');

    try {
      print("🔄 Starting Google login process");
      final user = await _authRepository.loginWithGoogle();
      if (user != null) {
        _currentUser = user;
        _currentUserData = await _getUserData(user.uid);
        _setNavigationTarget(_getRouteBasedOnRole());
        _setSuccess('Google sign in successful!');
        notifyListeners();
        return true;
      }
      _setError('Google sign in failed');
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError('');
    _setSuccess('');

    try {
      print("🔄 Starting login process for: $email");
      final user = await _authRepository.login(email, password);
      if (user != null) {
        _currentUser = user;
        _currentUserData = await _getUserData(user.uid);
        _setNavigationTarget(_getRouteBasedOnRole());
        _setSuccess('Login successful!');
        notifyListeners();
        return true;
      }
      _setError('Login failed');
      print("❌ Login failed - no user returned");
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      print("❌ Login error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setNavigationTarget(Widget target) {
    print("🎯 Setting navigation target: ${target.runtimeType}");
    _targetScreen = target;
    _shouldNavigate = true;
    print("🎯 Navigation state - shouldNavigate: $_shouldNavigate, targetScreen: ${_targetScreen != null}");
  }

  void clearNavigation() {
    _shouldNavigate = false;
    _targetScreen = null;
    print("🎯 Navigation cleared");
  }

  Future<bool> register(
    String email,
    String password,
    String name,
    String contact,
    String gender,
    String photoUrl,
  ) async {
    _setLoading(true);
    _setError('');
    _setSuccess('');

    try {
      final userData = Users(
        userId: '',
        name: name,
        email: email,
        contact: contact,
        gender: gender,
        role: 'member',
        photoUrl: photoUrl,
        creationDateTime: DateTime.now(),
      );

      final user = await _authRepository.register(email, password, userData);

      if (user != null) {
        _currentUser = user;
        _currentUserData = userData.copyWith(userId: user.uid);
        _setSuccess('Registration successful');
        return true;
      }
      _setError('Registration failed');
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerWithGoogle(String role) async {
    _setLoading(true);
    _setError('');
    _setSuccess('');

    try {
      final user = await _authRepository.registerWithGoogle();
      if (user != null) {
        _currentUser = user;

        final userData = Users(
          userId: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          contact: '',
          gender: '',
          role: role,
          photoUrl: user.photoURL ?? '',
          creationDateTime: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData.toMap());

        _currentUserData = userData;
        _setSuccess('Google registration successful!');
        return true;
      }
      _setError('Google registration failed');
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Stream<Users?> get userStream {
    return _authRepository.authStateChanges().asyncMap((user) async {
      print("🔄 Auth state changed: ${user?.uid}");
      
      if (user == null) {
        print("🚪 User signed out - returning null");
        return null;
      }
      
      try {
        final userData = await _getUserData(user.uid);
        print("📊 Stream: User data loaded - Role: ${userData?.role}");
        _currentUser = user;
        _currentUserData = userData;
        return userData;
      } catch (e) {
        print("❌ Stream error loading user data: $e");
        return null;
      }
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = '';
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _currentUser = null;
    _currentUserData = null;
    notifyListeners();
  }
}