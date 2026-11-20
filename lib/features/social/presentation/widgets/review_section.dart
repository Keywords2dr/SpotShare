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
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 5;
  bool _isSubmittingReview = false;
  String? _deletingReviewId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmittingReview) return;
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

    setState(() => _isSubmittingReview = true);
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
      setState(() => _selectedRating = 5);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi đánh giá và bình luận!')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi bình luận thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

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
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final reviewsAsync = ref.watch(spotReviewsProvider(widget.spot.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đánh giá & Bình luận (${widget.spot.ratingCount})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chấm điểm:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (int star = 1; star <= 5; star++)
                      InkWell(
                        onTap: _isSubmittingReview
                            ? null
                            : () => setState(() => _selectedRating = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            star <= _selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber.shade600,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  enabled: !_isSubmittingReview,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ trải nghiệm thực tế của bạn tại đây...',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: _isSubmittingReview ? null : _submitReview,
                    icon: _isSubmittingReview
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmittingReview ? 'Đang gửi...' : 'Gửi bình luận',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Không thể tải bình luận: $error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ đánh giá!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final review = reviews[index];
                final canDelete =
                    currentUserId != null && currentUserId == review.userId;
                return ReviewCard(
                  review: review,
                  formattedDate:
                      DateTimeHelper.formatFullPostTime(review.createdAt),
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