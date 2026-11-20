import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final FocusNode _commentFocusNode = FocusNode();

  bool _isTogglingLike = false;
  bool _isTogglingSave = false;
  bool _isDeletingSpot = false;

  @override
  void dispose() {
    _commentFocusNode.dispose();
    super.dispose();
  }

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

  Future<void> _copyCoordinates(SpotModel spot) async {
    final coords =
        '${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}';
    await Clipboard.setData(ClipboardData(text: coords));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép tọa độ: $coords')),
    );
  }

  Future<void> _confirmAndDeleteSpot(SpotModel spot) async {
    if (_isDeletingSpot) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != spot.authorId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bài đăng'),
        content: const Text(
          'Bạn có chắc muốn xóa bài đăng này không? Toàn bộ lượt thích và bình luận liên quan cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingSpot = true);
    try {
      await ref.read(spotRepositoryProvider).deleteSpot(
            spotId: spot.id,
            currentUserId: authUser.uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bài đăng.')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/explore');
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xóa bài đăng thất bại: $message')),
      );
      setState(() => _isDeletingSpot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(spotDetailProvider(widget.spotId));
    final spot = spotAsync.value ?? widget.initialSpot;

    if (spotAsync.isLoading && spot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (spot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Không tìm thấy địa điểm này hoặc bài viết đã bị xóa.'),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == spot.authorId;
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
    final colors = theme.colorScheme;
    final hasTags = spot.bestTimeTag.isNotEmpty ||
        spot.difficultyTag.isNotEmpty ||
        spot.priceTag.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 60,
        title: Row(
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spot.authorName.isNotEmpty
                        ? spot.authorName
                        : 'Thành viên SpotShare',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${DateTimeHelper.formatCardTime(spot.createdAt)} · ${spot.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: colors.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.public,
                        size: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isOwner)
            _isDeletingSpot
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: colors.onSurface,
                    ),
                    tooltip: 'Tùy chọn bài viết',
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push('/spots/${spot.id}/edit', extra: spot);
                      } else if (value == 'delete') {
                        _confirmAndDeleteSpot(spot);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 10),
                            Text('Chỉnh sửa bài viết'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: colors.error,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Xóa bài viết',
                              style: TextStyle(color: colors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Divider(
            height: 0.6,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (spot.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          spot.description,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: colors.onSurface.withValues(alpha: 0.88),
                            height: 1.48,
                          ),
                        ),
                      ],
                      if (spot.addressText.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                spot.addressText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SpotImageCarousel(images: spot.imageUrls),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _ActionCounterButton(
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: isLiked ? Colors.redAccent : null,
                        label: '${spot.likesCount}',
                        onTap: _isTogglingLike ? null : () => _toggleLike(spot),
                      ),
                      const SizedBox(width: 2),
                      _ActionCounterButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${spot.ratingCount}',
                        onTap: () => _commentFocusNode.requestFocus(),
                      ),
                      const SizedBox(width: 2),
                      _ActionCounterButton(
                        icon: isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        iconColor: isSaved ? colors.primary : null,
                        label: isSaved ? 'Đã lưu' : 'Lưu',
                        onTap: _isTogglingSave ? null : () => _toggleSave(spot),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 17,
                              color: Colors.amber.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              spot.ratingCount > 0
                                  ? spot.ratingAvg.toStringAsFixed(1)
                                  : 'Chưa có',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasTags || spot.latitude != 0 || spot.longitude != 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasTags)
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
                          if (hasTags) const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _copyCoordinates(spot),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tọa độ: ${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: ReviewSection(spot: spot),
                ),
              ],
            ),
          ),
          ReviewInputBar(
            spot: spot,
            focusNode: _commentFocusNode,
          ),
        ],
      ),
    );
  }
}

class _ActionCounterButton extends StatelessWidget {
  const _ActionCounterButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: iconColor ?? colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: iconColor ?? colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}