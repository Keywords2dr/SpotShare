import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginException implements Exception {
  const LoginException(
    this.message, {
    this.code,
    this.isCanceled = false,
    this.suggestPasswordReset = false,
  });

  final String message;
  final String? code;
  final bool isCanceled;
  final bool suggestPasswordReset;

  @override
  String toString() => message;
}

class LoginValidator {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? validateEmail(String? rawValue) {
    final email = rawValue?.trim() ?? '';
    if (email.isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Định dạng email không hợp lệ';
    }
    return null;
  }

  static String? validatePassword(String? rawValue) {
    final password = rawValue ?? '';
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }
}

abstract class LoginAuthGateway {
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();
}

class FirebaseLoginAuthGateway implements LoginAuthGateway {
  FirebaseLoginAuthGateway({
    this.firebaseAuth,
    this.firestore,
  });

  final FirebaseAuth? firebaseAuth;
  final FirebaseFirestore? firestore;

  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _ensureUserDocument(user);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (_) {
      throw const LoginException(
        'Không thể đăng nhập lúc này. Vui lòng kiểm tra kết nối mạng và thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});

      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        credential = await _auth.signInWithProvider(googleProvider);
      }

      final user = credential.user;
      if (user != null) {
        await _ensureUserDocument(user);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (_) {
      throw const LoginException(
        'Đăng nhập bằng Google thất bại. Vui lòng thử lại.',
        code: 'google-sign-in-failed',
      );
    }
  }

  Future<void> _ensureUserDocument(User user) async {
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      if (snapshot.exists) return;

      final fallbackName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Thành viên SpotShare');

      await docRef.set(
        {
          'uid': user.uid,
          'displayName': fallbackName,
          'email': user.email ?? '',
          'avatarUrl': user.photoURL ?? '',
          'bio': '',
          'spotsCount': 0,
          'totalLikes': 0,
          'followersCount': 0,
          'followingCount': 0,
          'fcmToken': '',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static LoginException _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return LoginException(
          'Email hoặc mật khẩu không chính xác.',
          code: e.code,
          suggestPasswordReset: true,
        );
      case 'invalid-email':
        return LoginException(
          'Địa chỉ email không hợp lệ.',
          code: e.code,
        );
      case 'user-disabled':
        return LoginException(
          'Tài khoản này đã bị vô hiệu hóa.',
          code: e.code,
        );
      case 'too-many-requests':
        return LoginException(
          'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng thử lại sau ít phút.',
          code: e.code,
        );
      case 'network-request-failed':
        return LoginException(
          'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.',
          code: e.code,
        );
      case 'popup-blocked':
        return LoginException(
          'Trình duyệt đang chặn cửa sổ đăng nhập Google. Hãy bật cho phép pop-up và thử lại.',
          code: e.code,
        );
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'canceled':
      case 'cancelled':
        return LoginException(
          '',
          code: e.code,
          isCanceled: true,
        );
      case 'account-exists-with-different-credential':
        return LoginException(
          'Email này đã liên kết với phương thức đăng nhập khác.',
          code: e.code,
        );
      case 'operation-not-allowed':
        return LoginException(
          'Phương thức đăng nhập này chưa được bật trên hệ thống.',
          code: e.code,
        );
      default:
        return LoginException(
          'Đăng nhập thất bại (${e.code}). Vui lòng thử lại.',
          code: e.code,
        );
    }
  }
}

final loginAuthGatewayProvider = Provider<LoginAuthGateway>((ref) {
  return FirebaseLoginAuthGateway();
});

enum _LoginMethod { email, google }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail = '',
    this.onForgotPassword,
    this.onRegister,
    this.onLoginSuccess,
    this.onContinueAsGuest,
  });

  final String initialEmail;
  final void Function(String email)? onForgotPassword;
  final VoidCallback? onRegister;
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onContinueAsGuest;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  _LoginMethod? _loadingMethod;
  String? _errorMessage;
  bool _suggestPasswordReset = false;

  bool get _isLoading => _loadingMethod != null;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null || _suggestPasswordReset) {
      setState(() {
        _errorMessage = null;
        _suggestPasswordReset = false;
      });
    }
  }

  Future<void> _signInWithEmail() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loadingMethod = _LoginMethod.email;
      _errorMessage = null;
      _suggestPasswordReset = false;
    });

    try {
      await ref.read(loginAuthGatewayProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
      });
      _handleLoginSuccess();
    } on LoginException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
        if (!e.isCanceled) {
          _errorMessage = e.message;
          _suggestPasswordReset = e.suggestPasswordReset;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loadingMethod = _LoginMethod.google;
      _errorMessage = null;
      _suggestPasswordReset = false;
    });

    try {
      await ref.read(loginAuthGatewayProvider).signInWithGoogle();
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
      });
      _handleLoginSuccess();
    } on LoginException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
        if (!e.isCanceled) {
          _errorMessage = e.message;
          _suggestPasswordReset = e.suggestPasswordReset;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMethod = null;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleLoginSuccess() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.go('/explore');
  }

  void _openForgotPassword() {
    final email = _emailController.text.trim();
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!(email);
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.push('/forgot-password', extra: email);
  }

  void _openRegister() {
    if (widget.onRegister != null) {
      widget.onRegister!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.push('/register');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 56,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SpotShare',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Khám phá & chia sẻ tọa độ du lịch thực chiến',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('login_email_field'),
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) =>
                            _passwordFocusNode.requestFocus(),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'vd: tenban@gmail.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: LoginValidator.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login_password_field'),
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) => _signInWithEmail(),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            key: const Key('login_toggle_password_button'),
                            tooltip: _obscurePassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: LoginValidator.validatePassword,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('login_forgot_password_button'),
                          onPressed: _isLoading ? null : _openForgotPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _LoginErrorBanner(
                          message: _errorMessage!,
                          showResetShortcut: _suggestPasswordReset,
                          onResetTap: _openForgotPassword,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('login_submit_button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : _signInWithEmail,
                        child: _loadingMethod == _LoginMethod.email
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: colors.outlineVariant,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Hoặc',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: colors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        key: const Key('login_google_button'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: _loadingMethod == _LoginMethod.google
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const _GoogleBadge(),
                        label: Text(
                          _loadingMethod == _LoginMethod.google
                              ? 'Đang kết nối Google...'
                              : 'Tiếp tục với Google',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            key: const Key('login_register_button'),
                            onPressed: _isLoading ? null : _openRegister,
                            child: const Text(
                              'Đăng ký ngay',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (widget.onContinueAsGuest != null) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          key: const Key('login_guest_button'),
                          onPressed:
                              _isLoading ? null : widget.onContinueAsGuest,
                          child: const Text('Khám phá với tư cách khách'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({
    required this.message,
    required this.showResetShortcut,
    required this.onResetTap,
  });

  final String message;
  final bool showResetShortcut;
  final VoidCallback onResetTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('login_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: colors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onErrorContainer,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (showResetShortcut) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('login_error_reset_shortcut'),
                onPressed: onResetTap,
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Đặt lại mật khẩu ngay',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}