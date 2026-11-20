import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../domain/user_model.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  late final _usersRef = _firestore.collection('users');

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Không thể khởi tạo tài khoản người dùng.');
      }

      final trimmedName = displayName.trim();
      await user.updateDisplayName(trimmedName);

      final userModel = UserModel(
        uid: user.uid,
        displayName: trimmedName,
        email: email.trim(),
      );

      await _usersRef.doc(user.uid).set(userModel.toCreateMap());
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});

      final credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);

      final user = credential.user;
      if (user == null) {
        throw Exception('Không thể lấy thông tin tài khoản Google.');
      }

      final docRef = _usersRef.doc(user.uid);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        final rawName = (user.displayName ?? '').trim();
        final fallbackName = (user.email ?? '').split('@').first;
        final resolvedName = rawName.isNotEmpty
            ? rawName
            : (fallbackName.isNotEmpty ? fallbackName : 'Thành viên SpotShare');

        final userModel = UserModel(
          uid: user.uid,
          displayName: resolvedName,
          email: user.email ?? '',
          avatarUrl: user.photoURL ?? '',
        );

        await docRef.set(userModel.toCreateMap());
        return userModel;
      }

      return UserModel.fromFirestore(snapshot);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Stream<UserModel?> watchUserProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromFirestore(snapshot);
    });
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email này đã được đăng ký trước đó.';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, cần tối thiểu 6 ký tự.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'popup-closed-by-user':
        return 'Bạn đã đóng cửa sổ đăng nhập Google.';
      case 'popup-blocked':
        return 'Trình duyệt đang chặn cửa sổ bật lên (Popup), vui lòng cho phép rồi thử lại.';
      case 'cancelled-popup-request':
        return 'Yêu cầu đăng nhập bị hủy, vui lòng thử lại.';
      case 'account-exists-with-different-credential':
        return 'Email này đã tồn tại với phương thức đăng nhập khác.';
      case 'unauthorized-domain':
        return 'Tên miền hiện tại chưa được cấp phép trong Firebase Authentication.';
      case 'too-many-requests':
        return 'Thử quá nhiều lần, vui lòng đợi ít phút.';
      case 'network-request-failed':
        return 'Không có kết nối mạng, vui lòng kiểm tra lại.';
      default:
        return 'Xác thực thất bại ($code).';
    }
  }
}