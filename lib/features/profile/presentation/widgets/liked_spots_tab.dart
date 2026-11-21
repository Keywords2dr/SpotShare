import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../data/liked_spots_repository.dart';
import '../liked_spots_controller.dart';

class LikedSpotsTab extends ConsumerStatefulWidget {
  const LikedSpotsTab({
    super.key,
    required this.userId,
    this.isOwnProfile = true,
    this.onSpotTap,
    this.onExploreTap,
  });

  final String userId;
  final bool isOwnProfile;
  final void Function(LikedSpotItem item)? onSpotTap;
  final VoidCallback? onExploreTap;

  @override
  ConsumerState<LikedSpotsTab> createState() => _LikedSpotsTabState();
}

class _LikedSpotsTabState extends ConsumerState<LikedSpotsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(likedSpotsControllerProvider.notifier).load(
            userId: widget.userId,
            cleanupOrphans: widget.isOwnProfile,
          );
    });
  }

  @override
  void didUpdateWidget(covariant LikedSpotsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(likedSpotsControllerProvider.notifier).load(
              userId: widget.userId,
              cleanupOrphans: widget.isOwnProfile,
            );
      });
    }
  }

  Future<void> _refresh() {
    return ref.read(likedSpotsControllerProvider.notifier).load(
          userId: widget.userId,
          forceRefresh: true,
          cleanupOrphans: widget.isOwnProfile,
        );
  }

  Future<void> _openSpot(LikedSpotItem item) async {
    if (widget.onSpotTap != null) {
      widget.onSpotTap!(item);
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      await router.push('/spots/${item.id}');
      if (mounted) {
        await _refresh();
      }
    }
  }

  void _openExplore() {
    if (widget.onExploreTap != null) {
      widget.onExploreTap!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.go('/explore');
  }

  Future<void> _unlikeItem(LikedSpotItem item) async {
    final error = await ref
        .read(likedSpotsControllerProvider.notifier)
        .unlikeSpot(userId: widget.userId, item: item);
    if (error != null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewState = ref.watch(
      likedSpotsControllerProvider.select(
        (map) => map[widget.userId] ?? const LikedSpotsViewState(),
      ),
    );

    if (viewState.isInitialLoading || (!viewState.hasLoaded && !viewState.isLoading)) {
      return const _LikedSpotsLoadingGrid();
    }

    if (viewState.errorMessage != null && viewState.items.isEmpty) {
      return _LikedSpotsMessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Không thể tải danh sách yêu thích',
        message: viewState.errorMessage!,
        actionLabel: 'Thử lại',
        actionKey: const Key('liked_spots_retry_button'),
        onAction: _refresh,
      );
    }

    if (viewState.items.isEmpty) {
      return _LikedSpotsMessageState(
        icon: Icons.favorite_border_rounded,
        title: widget.isOwnProfile
            ? 'Chưa có địa điểm yêu thích nào'
            : 'Người dùng này chưa thích địa điểm nào',
        message: widget.isOwnProfile
            ? 'Thả tim những bãi biển, góc chụp đẹp và quán ăn ngon bạn ấn tượng để xem lại nhanh tại đây.'
            : 'Các địa điểm được yêu thích sẽ hiển thị tại đây.',
        actionLabel: widget.isOwnProfile ? 'Khám phá ngay' : null,
        actionKey: const Key('liked_spots_explore_button'),
        onAction: widget.isOwnProfile ? _openExplore : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        key: const Key('liked_spots_grid'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: viewState.items.length,
        itemBuilder: (context, index) {
          final item = viewState.items[index];
          return _LikedSpotCard(
            item: item,
            canUnlike: widget.isOwnProfile,
            onTap: () => _openSpot(item),
            onUnlike: widget.isOwnProfile ? () => _unlikeItem(item) : null,
          );
        },
      ),
    );
  }
}

class _LikedSpotCard extends StatelessWidget {
  const _LikedSpotCard({
    required this.item,
    required this.canUnlike,
    required this.onTap,
    this.onUnlike,
  });

  final LikedSpotItem item;
  final bool canUnlike;
  final VoidCallback onTap;
  final VoidCallback? onUnlike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final thumbUrl = item.thumbnailUrl.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(item.thumbnailUrl)
        : '';

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('liked_spot_card_${item.id}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: colors.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => _ThumbnailPlaceholder(
                          colors: colors,
                        ),
                      )
                    else
                      _ThumbnailPlaceholder(colors: colors),
                    if (item.category.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 112),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.scrim.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (canUnlike && onUnlike != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: colors.surface.withValues(alpha: 0.88),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            key: Key('liked_spot_unlike_${item.id}'),
                            tooltip: 'Bỏ thích',
                            onPressed: onUnlike,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.favorite_rounded,
                              size: 17,
                              color: colors.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 13.5,
                            color: colors.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.likesCount}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.star_rounded,
                            size: 14.5,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.ratingCount > 0
                                ? item.ratingAvg.toStringAsFixed(1)
                                : '--',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.landscape_outlined,
        size: 32,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _LikedSpotsLoadingGrid extends StatelessWidget {
  const _LikedSpotsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      key: const Key('liked_spots_loading_grid'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

class _LikedSpotsMessageState extends StatelessWidget {
  const _LikedSpotsMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  key: actionKey,
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}