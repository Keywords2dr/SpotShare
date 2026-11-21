import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/password_reset_repository.dart';

final passwordResetRepositoryProvider =
    Provider<PasswordResetRepository>((ref) {
  return PasswordResetRepository();
});

class ForgotPasswordState {
  const ForgotPasswordState({
    this.isLoading = false,
    this.isSent = false,
    this.sentEmail = '',
    this.errorMessage,
    this.resendCooldownSeconds = 0,
  });

  final bool isLoading;
  final bool isSent;
  final String sentEmail;
  final String? errorMessage;
  final int resendCooldownSeconds;

  bool get canResend => !isLoading && resendCooldownSeconds == 0;

  ForgotPasswordState copyWith({
    bool? isLoading,
    bool? isSent,
    String? sentEmail,
    String? errorMessage,
    bool clearError = false,
    int? resendCooldownSeconds,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      isSent: isSent ?? this.isSent,
      sentEmail: sentEmail ?? this.sentEmail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
    );
  }
}

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  static const int cooldownDurationSeconds = 60;

  Timer? _cooldownTimer;

  @override
  ForgotPasswordState build() {
    ref.onDispose(() {
      _cooldownTimer?.cancel();
    });
    return const ForgotPasswordState();
  }

  Future<bool> submitResetEmail(String rawEmail) async {
    if (state.isLoading) return false;

    final normalizedEmail = rawEmail.trim().toLowerCase();
    if (state.resendCooldownSeconds > 0 && state.sentEmail == normalizedEmail) {
      return false;
    }

    final validationError =
        PasswordResetRepository.validateEmail(normalizedEmail);
    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError);
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await ref
          .read(passwordResetRepositoryProvider)
          .sendPasswordResetEmail(normalizedEmail);

      state = state.copyWith(
        isLoading: false,
        isSent: true,
        sentEmail: normalizedEmail,
        clearError: true,
        resendCooldownSeconds: cooldownDurationSeconds,
      );
      _startCooldownTimer();
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void editAnotherEmail() {
    _cooldownTimer?.cancel();
    state = const ForgotPasswordState();
  }

  void reset() {
    if (!state.isLoading &&
        !state.isSent &&
        state.errorMessage == null &&
        state.resendCooldownSeconds == 0 &&
        state.sentEmail.isEmpty) {
      return;
    }
    _cooldownTimer?.cancel();
    state = const ForgotPasswordState();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.resendCooldownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(resendCooldownSeconds: 0);
      } else {
        state = state.copyWith(resendCooldownSeconds: next);
      }
    });
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
  ForgotPasswordController.new,
);