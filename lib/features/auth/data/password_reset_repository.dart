import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetException implements Exception {
  const PasswordResetException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class PasswordResetRepository {
  PasswordResetRepository({this.firebaseAuth});

  final FirebaseAuth? firebaseAuth;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? validateEmail(String? rawEmail) {
    final email = rawEmail?.trim() ?? '';
    if (email.isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Định dạng email không hợp lệ';
    }
    return null;
  }

  Future<void> sendPasswordResetEmail(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    final validationError = validateEmail(email);
    if (validationError != null) {
      throw PasswordResetException(validationError, code: 'invalid-email');
    }

    final auth = firebaseAuth ?? FirebaseAuth.instance;
    try {
      await auth.setLanguageCode('vi');
    } catch (_) {}

    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw PasswordResetException(_mapErrorCode(e.code), code: e.code);
    } catch (_) {
      throw const PasswordResetException(
        'Không thể gửi yêu cầu lúc này. Vui lòng kiểm tra kết nối mạng và thử lại.',
        code: 'unknown',
      );
    }
  }

  static String _mapErrorCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản nào đăng ký với email này.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
      default:
        return 'Gửi email đặt lại mật khẩu thất bại ($code). Vui lòng thử lại.';
    }
  }
}