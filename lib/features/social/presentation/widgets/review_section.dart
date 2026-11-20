import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_helper.dart';
import '../../../spots/domain/spot_model.dart';
import '../../domain/review_model.dart';
import '../social_providers.dart';
import 'review_card.dart';

class ReviewSection extends ConsumerStatefulWidget {
  const ReviewSection({
    super.key,
    required this.spot,
  });

  final SpotModel spot;

  @override
  ConsumerState<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<ReviewSection> {
  String? _deletingReviewId;

  Future<void> _confirmAndDeleteReview(ReviewModel review) async {
    if (_deletingReviewId != null) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != review.userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bình luận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingReviewId = review.id);
    try {
      await ref.read(reviewRepositoryProvider).deleteReview(
            spotId: widget.spot.id,
            reviewId: review.id,
            userId: authUser.uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bình luận.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xóa bình luận thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingReviewId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final reviewsAsync = ref.watch(spotReviewsProvider(widget.spot.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bình luận',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            if (widget.spot.ratingCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '${widget.spot.ratingCount}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Không thể tải bình luận: $error',
              style: TextStyle(
                fontSize: 14,
                color: colors.error,
              ),
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ đánh giá!',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final review = reviews[index];
                final canDelete =
                    currentUserId != null && currentUserId == review.userId;
                return ReviewCard(
                  review: review,
                  spotAuthorId: widget.spot.authorId,
                  formattedDate: DateTimeHelper.formatCardTime(review.createdAt),
                  canDelete: canDelete,
                  isDeleting: _deletingReviewId == review.id,
                  onDelete:
                      canDelete ? () => _confirmAndDeleteReview(review) : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class ReviewInputBar extends ConsumerStatefulWidget {
  const ReviewInputBar({
    super.key,
    required this.spot,
    required this.focusNode,
  });

  final SpotModel spot;
  final FocusNode focusNode;

  @override
  ConsumerState<ReviewInputBar> createState() => _ReviewInputBarState();
}

class _ReviewInputBarState extends ConsumerState<ReviewInputBar> {
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 5;
  bool _isSubmitting = false;
  bool _showRatingPicker = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ReviewInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _commentController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus && !_showRatingPicker) {
      setState(() => _showRatingPicker = true);
    } else if (!widget.focusNode.hasFocus &&
        _commentController.text.trim().isEmpty &&
        _showRatingPicker) {
      setState(() => _showRatingPicker = false);
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để bình luận.')),
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung bình luận.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final fallbackName = (authUser.displayName ?? '').trim().isNotEmpty
          ? authUser.displayName!.trim()
          : (authUser.email ?? 'Thành viên SpotShare').split('@').first;
      final fallbackAvatar = authUser.photoURL ?? '';

      await ref.read(reviewRepositoryProvider).addReview(
            spotId: widget.spot.id,
            userId: authUser.uid,
            userName: fallbackName,
            userAvatar: fallbackAvatar,
            rating: _selectedRating,
            comment: text,
          );

      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _selectedRating = 5;
        _showRatingPicker = false;
      });
      widget.focusNode.unfocus();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi bình luận thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showRatingPicker)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Đánh giá:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (int star = 1; star <= 5; star++)
                        InkWell(
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _selectedRating = star),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              star <= _selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber.shade600,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(
                              () => _showRatingPicker = !_showRatingPicker,
                            ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$_selectedRating',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: widget.focusNode,
                      enabled: !_isSubmitting,
                      minLines: 1,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitReview(),
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    tooltip: 'Gửi bình luận',
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 21,
                            color: colors.primary,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}