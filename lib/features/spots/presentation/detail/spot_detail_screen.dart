import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../../../core/utils/date_time_helper.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../../social/presentation/social_providers.dart';
import '../../../social/presentation/widgets/review_section.dart';
import '../../domain/spot_model.dart';
import '../spot_providers.dart';
import 'widgets/spot_image_carousel.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({
    super.key,
    required this.spotId,
    this.initialSpot,
  });

  final String spotId;
  final SpotModel? initialSpot;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  bool _isTogglingLike = false;
  bool _isTogglingSave = false;

  Future<void> _toggleLike(SpotModel spot) async {
    if (_isTogglingLike) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thả tim.')),
      );
      return;
    }

    setState(() => _isTogglingLike = true);
    try {
      await ref.read(interactionRepositoryProvider).toggleLike(
            spotId: spot.id,
            userId: authUser.uid,
            authorId: spot.authorId,
          );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật lượt thích: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTogglingLike = false);
      }
    }
  }

  Future<void> _toggleSave(SpotModel spot) async {
    if (_isTogglingSave) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu địa điểm.')),
      );
      return;
    }

    setState(() => _isTogglingSave = true);
    try {
      final saved =
          await ref.read(interactionRepositoryProvider).toggleSaveSpot(
                spotId: spot.id,
                userId: authUser.uid,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Đã lưu vào mục Đã lưu.' : 'Đã bỏ khỏi mục Đã lưu.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu địa điểm: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTogglingSave = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(spotDetailProvider(widget.spotId));
    final spot = spotAsync.value ?? widget.initialSpot;

    if (spotAsync.isLoading && spot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết địa điểm')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (spot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết địa điểm')),
        body: const Center(
          child: Text('Không tìm thấy địa điểm này hoặc bài viết đã bị xóa.'),
        ),
      );
    }

    final isLiked = ref.watch(spotLikedProvider(spot.id)).value ?? false;
    final isSaved = ref.watch(spotSavedProvider(spot.id)).value ?? false;
    final liveAuthorAvatar =
        ref.watch(userAvatarProvider(spot.authorId)).value ?? '';
    final rawAuthorAvatar =
        liveAuthorAvatar.isNotEmpty ? liveAuthorAvatar : spot.authorAvatar;
    final authorAvatarUrl = rawAuthorAvatar.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(rawAuthorAvatar)
        : '';

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          spot.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          SpotImageCarousel(images: spot.imageUrls),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        spot.category,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      spot.ratingCount > 0
                          ? '${spot.ratingAvg.toStringAsFixed(1)} (${spot.ratingCount})'
                          : 'Chưa có đánh giá',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  spot.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: authorAvatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(authorAvatarUrl)
                          : null,
                      child: authorAvatarUrl.isEmpty
                          ? Text(
                              spot.authorName.isNotEmpty
                                  ? spot.authorName[0].toUpperCase()
                                  : 'S',
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.authorName.isNotEmpty
                                ? spot.authorName
                                : 'Thành viên SpotShare',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateTimeHelper.formatFullPostTime(spot.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed:
                          _isTogglingSave ? null : () => _toggleSave(spot),
                      tooltip: isSaved ? 'Bỏ lưu' : 'Lưu địa điểm',
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isSaved ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed:
                          _isTogglingLike ? null : () => _toggleLike(spot),
                      icon: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.redAccent : null,
                      ),
                      label: Text('${spot.likesCount}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (spot.bestTimeTag.isNotEmpty)
                      _QuickTagChip(
                        icon: Icons.wb_sunny_outlined,
                        label: spot.bestTimeTag,
                      ),
                    if (spot.difficultyTag.isNotEmpty)
                      _QuickTagChip(
                        icon: Icons.directions_bike_outlined,
                        label: spot.difficultyTag,
                      ),
                    if (spot.priceTag.isNotEmpty)
                      _QuickTagChip(
                        icon: Icons.payments_outlined,
                        label: spot.priceTag,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Địa chỉ & Tọa độ',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                spot.addressText.isNotEmpty
                                    ? spot.addressText
                                    : 'Chưa cập nhật địa chỉ',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'GPS: ${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Trải nghiệm thực tế',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  spot.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ReviewSection(spot: spot),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTagChip extends StatelessWidget {
  const _QuickTagChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}