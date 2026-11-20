import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../domain/review_model.dart';

class ReviewCard extends ConsumerWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.spotAuthorId,
    required this.formattedDate,
    required this.canDelete,
    required this.isDeleting,
    this.onDelete,
  });

  final ReviewModel review;
  final String spotAuthorId;
  final String formattedDate;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final liveAvatar = ref.watch(userAvatarProvider(review.userId)).value ?? '';
    final rawAvatar = liveAvatar.isNotEmpty ? liveAvatar : review.userAvatar;
    final avatarUrl =
        rawAvatar.isNotEmpty ? CloudinaryUrlHelper.feedThumbnail(rawAvatar) : '';
    final isAuthor = spotAuthorId.isNotEmpty && review.userId == spotAuthorId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? Text(
                  review.userName.isNotEmpty
                      ? review.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    review.userName.isNotEmpty
                        ? review.userName
                        : 'Thành viên SpotShare',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                      height: 1.25,
                    ),
                  ),
                  if (isAuthor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tác giả',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Text(
                    '· $formattedDate',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                review.comment,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurface.withValues(alpha: 0.9),
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${review.rating}/5',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 16),
                    isDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                'Xóa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}