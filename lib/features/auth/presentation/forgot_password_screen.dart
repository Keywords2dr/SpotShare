import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/password_reset_repository.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.onBackToLogin,
  });

  final String initialEmail;
  final VoidCallback? onBackToLogin;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(forgotPasswordControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submitResetEmail(_emailController.text);
  }

  Future<void> _resend(String email) async {
    final sent = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submitResetEmail(email);
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi lại liên kết đặt lại mật khẩu.'),
        ),
      );
    }
  }

  void _handleBackToLogin() {
    if (widget.onBackToLogin != null) {
      widget.onBackToLogin!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/login');
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _handleBackToLogin,
          tooltip: 'Quay lại đăng nhập',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Quên mật khẩu'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: state.isSent
                  ? _SentConfirmationView(
                      state: state,
                      onResend: () => _resend(state.sentEmail),
                      onEditEmail: () {
                        _emailController.text = state.sentEmail;
                        ref
                            .read(forgotPasswordControllerProvider.notifier)
                            .editAnotherEmail();
                      },
                      onBackToLogin: _handleBackToLogin,
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 36,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Đặt lại mật khẩu',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhập email bạn đã dùng để đăng ký SpotShare. Chúng tôi sẽ gửi liên kết tạo mật khẩu mới vào hộp thư của bạn.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            enabled: !state.isLoading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => ref
                                .read(forgotPasswordControllerProvider.notifier)
                                .clearError(),
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'vd: tenban@gmail.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: PasswordResetRepository.validateEmail,
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            _ErrorBanner(message: state.errorMessage!),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            onPressed: state.isLoading ? null : _submit,
                            icon: state.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              state.isLoading
                                  ? 'Đang gửi liên kết...'
                                  : 'Gửi liên kết đặt lại mật khẩu',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nếu bạn đăng nhập bằng Google, hãy quay lại và chọn "Tiếp tục với Google" thay vì đặt lại mật khẩu.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed:
                                state.isLoading ? null : _handleBackToLogin,
                            child: const Text('Quay lại đăng nhập'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentConfirmationView extends StatelessWidget {
  const _SentConfirmationView({
    required this.state,
    required this.onResend,
    required this.onEditEmail,
    required this.onBackToLogin,
  });

  final ForgotPasswordState state;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 38,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kiểm tra hộp thư của bạn',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Nếu email dưới đây đã đăng ký bằng mật khẩu trên SpotShare, liên kết đặt lại mật khẩu đã được gửi tới:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            state.sentEmail,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Mẹo: Nếu chưa thấy sau 1–2 phút, hãy kiểm tra thêm mục Thư rác (Spam) hoặc Quảng cáo.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: state.errorMessage!),
        ],
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: onBackToLogin,
          child: const Text(
            'Quay lại đăng nhập',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
          ),
          onPressed: state.canResend ? onResend : null,
          icon: state.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            state.resendCooldownSeconds > 0
                ? 'Gửi lại sau ${state.resendCooldownSeconds}s'
                : 'Gửi lại email',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.isLoading ? null : onEditEmail,
          child: const Text('Thử với email khác'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
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
    );
  }
}