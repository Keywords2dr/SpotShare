import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/auth/data/password_reset_repository.dart';
import 'package:spotshare/features/auth/presentation/forgot_password_controller.dart';
import 'package:spotshare/features/auth/presentation/forgot_password_screen.dart';

class FakePasswordResetRepository extends PasswordResetRepository {
  FakePasswordResetRepository({this.errorToThrow});

  Object? errorToThrow;
  final List<String> sentEmails = [];

  @override
  Future<void> sendPasswordResetEmail(String rawEmail) async {
    final normalized = rawEmail.trim().toLowerCase();
    final validationError = PasswordResetRepository.validateEmail(normalized);
    if (validationError != null) {
      throw PasswordResetException(validationError, code: 'invalid-email');
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    sentEmails.add(normalized);
  }
}

void main() {
  group('PasswordResetRepository.validateEmail', () {
    test('rejects empty and malformed emails', () {
      expect(PasswordResetRepository.validateEmail(''), isNotNull);
      expect(PasswordResetRepository.validateEmail('   '), isNotNull);
      expect(PasswordResetRepository.validateEmail('teoem'), isNotNull);
      expect(PasswordResetRepository.validateEmail('teoem@'), isNotNull);
      expect(PasswordResetRepository.validateEmail('teoem@gmail'), isNotNull);
      expect(
        PasswordResetRepository.validateEmail('teo em@gmail.com'),
        isNotNull,
      );
    });

    test('accepts valid emails', () {
      expect(PasswordResetRepository.validateEmail('teoem@gmail.com'), isNull);
      expect(
        PasswordResetRepository.validateEmail('  Teo.Em+1@qnu.edu.vn  '),
        isNull,
      );
    });
  });

  group('ForgotPasswordController', () {
    test('normalizes email, sends link, and starts 60s cooldown', () async {
      final fakeRepo = FakePasswordResetRepository();
      final container = ProviderContainer(
        overrides: [
          passwordResetRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(forgotPasswordControllerProvider.notifier);
      final ok = await controller.submitResetEmail('  TeoEm@Gmail.COM  ');

      expect(ok, isTrue);
      expect(fakeRepo.sentEmails, ['teoem@gmail.com']);

      final state = container.read(forgotPasswordControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSent, isTrue);
      expect(state.sentEmail, 'teoem@gmail.com');
      expect(state.resendCooldownSeconds, 60);
      expect(state.canResend, isFalse);

      final duplicate = await controller.submitResetEmail('teoem@gmail.com');
      expect(duplicate, isFalse);
      expect(fakeRepo.sentEmails.length, 1);
    });

    test('exposes error message and keeps form active on failure', () async {
      final fakeRepo = FakePasswordResetRepository(
        errorToThrow: const PasswordResetException(
          'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.',
          code: 'network-request-failed',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          passwordResetRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(forgotPasswordControllerProvider.notifier);
      final ok = await controller.submitResetEmail('teoem@gmail.com');

      expect(ok, isFalse);
      final state = container.read(forgotPasswordControllerProvider);
      expect(state.isSent, isFalse);
      expect(state.errorMessage, contains('Mất kết nối mạng'));
      expect(state.resendCooldownSeconds, 0);
    });
  });

  group('ForgotPasswordScreen widget tests', () {
    testWidgets('pre-fills email, sends reset link, and counts down cooldown',
        (tester) async {
      final fakeRepo = FakePasswordResetRepository();
      var backTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passwordResetRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: ForgotPasswordScreen(
              initialEmail: 'teoem@gmail.com',
              onBackToLogin: () => backTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('teoem@gmail.com'), findsOneWidget);

      await tester.tap(find.text('Gửi liên kết đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentEmails, ['teoem@gmail.com']);
      expect(find.text('Kiểm tra hộp thư của bạn'), findsOneWidget);
      expect(find.text('Gửi lại sau 60s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Gửi lại sau 59s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Gửi lại email'), findsOneWidget);

      final editEmailButton = find.text('Thử với email khác');
      await tester.ensureVisible(editEmailButton);
      await tester.pumpAndSettle();
      await tester.tap(editEmailButton);
      await tester.pumpAndSettle();
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);

      final backButton = find.text('Quay lại đăng nhập');
      await tester.ensureVisible(backButton);
      await tester.pumpAndSettle();
      await tester.tap(backButton);
      await tester.pump();
      expect(backTapped, isTrue);
    });

    testWidgets(
        'blocks submission on invalid email and shows error banner on failure',
        (tester) async {
      final fakeRepo = FakePasswordResetRepository(
        errorToThrow: const PasswordResetException(
          'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.',
          code: 'too-many-requests',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passwordResetRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'khong-hop-le');
      await tester.tap(find.text('Gửi liên kết đặt lại mật khẩu'));
      await tester.pump();

      expect(find.text('Định dạng email không hợp lệ'), findsOneWidget);
      expect(fakeRepo.sentEmails, isEmpty);

      await tester.enterText(find.byType(TextFormField), 'teoem@gmail.com');
      await tester.tap(find.text('Gửi liên kết đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(find.textContaining('quá nhiều yêu cầu'), findsOneWidget);
      expect(find.text('Kiểm tra hộp thư của bạn'), findsNothing);
    });
  });
}