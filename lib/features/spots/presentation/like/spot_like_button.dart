import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spot_like_controller.dart';

class SpotLikeButton extends ConsumerWidget {
  const SpotLikeButton({
    super.key,
    required this.spotId,
    required this.initialLikesCount,
    required this.initialIsLiked,
    this.userId,
    this.authorId,
    this.onRequireLogin,
    this.onError,
  });

  final String spotId;
  final int initialLikesCount;
  final bool initialIsLiked;
  final String? userId;
  final String? authorId;
  final VoidCallback? onRequireLogin;
  final void Function(String message)? onError;

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final uid = userId?.trim() ?? '';
    if (uid.isEmpty) {
      if (onRequireLogin != null) {
        onRequireLogin!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thả tim địa điểm.'),
          ),
        );
      }
      return;
    }

    final outcome =
        await ref.read(spotLikeControllerProvider.notifier).toggleLike(
              spotId: spotId,
              userId: uid,
              fallbackIsLiked: initialIsLiked,
              fallbackLikesCount: initialLikesCount,
              authorId: authorId,
            );

    if (!outcome.success && !outcome.ignored && outcome.errorMessage != null) {
      if (onError != null) {
        onError!(outcome.errorMessage!);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.errorMessage!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrideState = ref.watch(
      spotLikeControllerProvider.select((map) => map[spotId]),
    );

    final isLiked = overrideState?.isLiked ?? initialIsLiked;
    final likesCount = overrideState?.likesCount ??
        (initialLikesCount < 0 ? 0 : initialLikesCount);
    final isProcessing = overrideState?.isProcessing ?? false;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeColor = colors.error;
    final inactiveColor = colors.onSurfaceVariant;

    return Tooltip(
      message: isLiked ? 'Bỏ thích' : 'Thích địa điểm',
      child: InkWell(
        key: Key('spot_like_button_$spotId'),
        borderRadius: BorderRadius.circular(20),
        onTap: isProcessing ? null : () => _handleTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isLiked ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: Key('spot_like_icon_$spotId'),
                  size: 22,
                  color: isLiked ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$likesCount',
                key: Key('spot_like_count_$spotId'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isLiked ? FontWeight.w700 : FontWeight.w500,
                  color: isLiked ? activeColor : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}