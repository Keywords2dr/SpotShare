import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/auth/presentation/login_screen.dart';

class FakeLoginAuthGateway implements LoginAuthGateway {
  FakeLoginAuthGateway({
    this.emailError,
    this.googleError,
    this.emailCompleter,
  });

  Object? emailError;
  Object? googleError;
  Completer<void>? emailCompleter;

  final List<({String email, String password})> emailCalls = [];
  int googleCalls = 0;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailCalls.add((email: email, password: password));
    if (emailCompleter != null) {
      await emailCompleter!.future;
    }
    if (emailError != null) {
      throw emailError!;
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    if (googleError != null) {
      throw googleError!;
    }
  }
}

void main() {
  group('LoginValidator', () {
    test('rejects invalid emails and accepts valid emails', () {
      expect(LoginValidator.validateEmail(''), isNotNull);
      expect(LoginValidator.validateEmail('   '), isNotNull);
      expect(LoginValidator.validateEmail('invalid-email'), isNotNull);
      expect(LoginValidator.validateEmail('user@domain'), isNotNull);
      expect(LoginValidator.validateEmail('user@gmail.com'), isNull);
      expect(LoginValidator.validateEmail('  User.Test+1@qnu.edu.vn  '), isNull);
    });

    test('enforces minimum 6 characters password per FR-01', () {
      expect(LoginValidator.validatePassword(''), isNotNull);
      expect(LoginValidator.validatePassword('12345'), isNotNull);
      expect(LoginValidator.validatePassword('123456'), isNull);
    });
  });

  group('LoginScreen widget tests', () {
    testWidgets('blocks empty/invalid submission without calling gateway',
        (tester) async {
      final fakeGateway = FakeLoginAuthGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginAuthGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Vui lòng nhập địa chỉ email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(fakeGateway.emailCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'sai-dinh-dang',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Định dạng email không hợp lệ'), findsOneWidget);
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
      expect(fakeGateway.emailCalls, isEmpty);
    });

    testWidgets(
        'submits trimmed email, toggles password visibility, and triggers success callback',
        (tester) async {
      final completer = Completer<void>();
      final fakeGateway = FakeLoginAuthGateway(emailCompleter: completer);
      var loggedIn = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginAuthGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            home: LoginScreen(
              onLoginSuccess: () => loggedIn = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('login_toggle_password_button')));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        '  teoem@gmail.com  ',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('login_google_button')));
      await tester.pump();
      expect(fakeGateway.googleCalls, 0);

      completer.complete();
      await tester.pumpAndSettle();

      expect(fakeGateway.emailCalls.length, 1);
      expect(fakeGateway.emailCalls.first.email, 'teoem@gmail.com');
      expect(fakeGateway.emailCalls.first.password, 'secret123');
      expect(loggedIn, isTrue);
    });

    testWidgets(
        'shows error banner with reset shortcut on invalid credentials and clears on edit',
        (tester) async {
      final fakeGateway = FakeLoginAuthGateway(
        emailError: const LoginException(
          'Email hoặc mật khẩu không chính xác.',
          code: 'invalid-credential',
          suggestPasswordReset: true,
        ),
      );
      String? forwardedEmail;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginAuthGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            home: LoginScreen(
              onForgotPassword: (email) => forwardedEmail = email,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'teoem@gmail.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'wrongpass',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Email hoặc mật khẩu không chính xác.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('login_error_reset_shortcut')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('login_error_reset_shortcut')));
      await tester.pump();
      expect(forwardedEmail, 'teoem@gmail.com');

      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'newattempt',
      );
      await tester.pump();
      expect(find.byKey(const Key('login_error_banner')), findsNothing);
    });

    testWidgets('handles Google Sign-In cancel silently and navigation actions',
        (tester) async {
      final fakeGateway = FakeLoginAuthGateway(
        googleError: const LoginException(
          '',
          code: 'popup-closed-by-user',
          isCanceled: true,
        ),
      );
      String? forgotEmail;
      var registerTapped = false;
      var guestTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginAuthGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            home: LoginScreen(
              initialEmail: 'user@qnu.edu.vn',
              onForgotPassword: (email) => forgotEmail = email,
              onRegister: () => registerTapped = true,
              onContinueAsGuest: () => guestTapped = true,
            ),
          ),
        ),
      );

      final googleButton = find.byKey(const Key('login_google_button'));
      await tester.ensureVisible(googleButton);
      await tester.pumpAndSettle();
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(fakeGateway.googleCalls, 1);
      expect(find.byKey(const Key('login_error_banner')), findsNothing);

      final forgotButton = find.byKey(const Key('login_forgot_password_button'));
      await tester.ensureVisible(forgotButton);
      await tester.pumpAndSettle();
      await tester.tap(forgotButton);
      await tester.pump();
      expect(forgotEmail, 'user@qnu.edu.vn');

      final registerButton = find.byKey(const Key('login_register_button'));
      await tester.ensureVisible(registerButton);
      await tester.pumpAndSettle();
      await tester.tap(registerButton);
      await tester.pump();
      expect(registerTapped, isTrue);

      final guestButton = find.byKey(const Key('login_guest_button'));
      await tester.ensureVisible(guestButton);
      await tester.pumpAndSettle();
      await tester.tap(guestButton);
      await tester.pump();
      expect(guestTapped, isTrue);
    });

    testWidgets('renders cleanly in Dark Mode on compact 5.5 inch viewport',
        (tester) async {
      final fakeGateway = FakeLoginAuthGateway();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginAuthGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SpotShare'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
    });
  });
}