import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/cloudinary_url_helper.dart';
import '../../spots/presentation/like/spot_like_controller.dart';
import '../data/explore_feed_repository.dart';
import 'explore_feed_controller.dart';
import 'widgets/compact_explore_header.dart';
import 'widgets/explore_filter_sheet.dart';

class ExploreFeedScreen extends ConsumerStatefulWidget {
  const ExploreFeedScreen({
    super.key,
    this.onSpotTap,
    this.onUserTap,
    this.onCreateTap,
  });

  final FutureOr<void> Function(ExploreSpotSummary spot)? onSpotTap;
  final void Function(ExploreUserHit user)? onUserTap;
  final VoidCallback? onCreateTap;

  @override
  ConsumerState<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends ConsumerState<ExploreFeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = ref.read(exploreCurrentUserIdProvider)?.trim() ?? '';
      if (uid.isNotEmpty) {
        ref.read(exploreFeedControllerProvider.notifier).loadInitial();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(exploreFeedControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(exploreFeedControllerProvider.notifier).setSearchQuery('');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(exploreFeedControllerProvider.notifier).setSearchQuery(value);
    });
  }

  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();
    ref.read(exploreFeedControllerProvider.notifier).setSearchQuery(value);
  }

  Future<void> _openFilterSheet() async {
    final current = ref.read(exploreFeedControllerProvider);
    final selection = await showModalBottomSheet<ExploreFilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExploreFilterSheet(
        initialCategory: current.selectedCategory,
        initialPrice: current.selectedPrice,
        initialBestTime: current.selectedBestTime,
      ),
    );
    if (selection == null || !mounted) return;
    ref.read(exploreFeedControllerProvider.notifier).applyFilters(
          category: selection.category,
          price: selection.price,
          bestTime: selection.bestTime,
        );
  }

  Future<void> _openSpot(ExploreSpotSummary spot) async {
    if (widget.onSpotTap != null) {
      await widget.onSpotTap!(spot);
      if (mounted) {
        await ref
            .read(exploreFeedControllerProvider.notifier)
            .syncSpotById(spot.id);
      }
      return;
    }

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      await router.push('/spots/${spot.id}');
      if (mounted) {
        await ref
            .read(exploreFeedControllerProvider.notifier)
            .syncSpotById(spot.id);
      }
    }
  }

  void _openUser(ExploreUserHit user) {
    if (widget.onUserTap != null) {
      widget.onUserTap!(user);
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.push('/users/${user.uid}');
  }

  void _openCreate() {
    if (widget.onCreateTap != null) {
      widget.onCreateTap!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.go('/create');
  }

  void _clearAllFiltersAndQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref
        .read(exploreFeedControllerProvider.notifier)
        .clearFilters(clearQuery: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(exploreCurrentUserIdProvider, (previous, next) {
      final nextUid = (next ?? '').trim();
      final prevUid = (previous ?? '').trim();
      if (nextUid.isNotEmpty && nextUid != prevUid) {
        Future<void>.microtask(() {
          if (!mounted) return;
          ref.read(exploreFeedControllerProvider.notifier).loadInitial();
        });
      }
    });

    final state = ref.watch(exploreFeedControllerProvider);
    final likeOverrides = ref.watch(spotLikeControllerProvider);
    final visibleSpots = state.visibleSpots;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CompactExploreHeader(
              title: 'Trang chủ',
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: _onSearchSubmitted,
              selectedSort: state.sortOption,
              onSortChanged: (option) =>
                  ref.read(exploreFeedControllerProvider.notifier).setSort(
                        option,
                      ),
              activeFilterCount: state.activeFilterCount,
              onFilterTap: _openFilterSheet,
            ),
            Divider(
              height: 0.6,
              thickness: 0.6,
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
            if (state.activeFilterCount > 0)
              _ActiveFilterBar(
                selectedCategory:
                    state.hasActiveCategory ? state.selectedCategory : null,
                selectedPrice: state.selectedPrice,
                selectedBestTime: state.selectedBestTime,
                onRemoveCategory: () => ref
                    .read(exploreFeedControllerProvider.notifier)
                    .setCategory(ExploreFeedFilterPresets.allCategory),
                onRemovePrice: () => ref
                    .read(exploreFeedControllerProvider.notifier)
                    .applyFilters(
                      category: state.selectedCategory,
                      price: null,
                      bestTime: state.selectedBestTime,
                    ),
                onRemoveTime: () => ref
                    .read(exploreFeedControllerProvider.notifier)
                    .applyFilters(
                      category: state.selectedCategory,
                      price: state.selectedPrice,
                      bestTime: null,
                    ),
                onClearAll: () => ref
                    .read(exploreFeedControllerProvider.notifier)
                    .clearFilters(),
              ),
            if (state.errorMessage != null && state.spots.isNotEmpty)
              Material(
                color: colors.errorContainer.withValues(alpha: 0.78),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 15,
                        color: colors.onErrorContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(exploreFeedControllerProvider.notifier)
                            .refresh(),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onErrorContainer,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Thử lại',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      ExploreFeedLogic.resolveGridCrossAxisCount(
                    constraints.maxWidth,
                  );
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final cardExtent =
                      ExploreFeedLogic.resolveCardMainAxisExtent(textScale);

                  return _buildBody(
                    context: context,
                    state: state,
                    visibleSpots: visibleSpots,
                    likeOverrides: likeOverrides,
                    crossAxisCount: crossAxisCount,
                    cardExtent: cardExtent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ExploreFeedState state,
    required List<ExploreSpotSummary> visibleSpots,
    required SpotLikeStateMap likeOverrides,
    required int crossAxisCount,
    required double cardExtent,
  }) {
    if (state.isInitialLoading || (!state.hasLoaded && state.spots.isEmpty)) {
      return _ExploreLoadingSkeletonGrid(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: cardExtent,
      );
    }

    if (state.errorMessage != null && state.spots.isEmpty) {
      return _ExploreStateMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Không thể tải bảng tin',
        message: state.errorMessage!,
        actionLabel: 'Thử lại',
        actionKey: const Key('explore_retry_button'),
        onAction: () =>
            ref.read(exploreFeedControllerProvider.notifier).refresh(),
      );
    }

    final hasUsersSection =
        state.isSearchingUsers || state.matchedUsers.isNotEmpty;

    if (visibleSpots.isEmpty && !hasUsersSection) {
      if (state.hasAnyCriteria) {
        return _ExploreStateMessage(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy địa điểm phù hợp',
          message:
              'Thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt bộ lọc danh mục, khoảng giá và khung giờ.',
          actionLabel: 'Xóa bộ lọc',
          actionKey: const Key('explore_clear_filters_button'),
          onAction: _clearAllFiltersAndQuery,
        );
      }

      return _ExploreStateMessage(
        icon: Icons.explore_outlined,
        title: 'Chưa có tọa độ nào được chia sẻ',
        message:
            'Hãy là người đầu tiên chia sẻ bãi biển, cảnh đẹp hoặc quán ăn yêu thích của bạn.',
        actionLabel: 'Đăng bài ngay',
        actionKey: const Key('explore_create_first_button'),
        onAction: _openCreate,
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(exploreFeedControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        key: const Key('explore_feed_scroll'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (hasUsersSection)
            SliverToBoxAdapter(
              child: _MatchedUsersStrip(
                users: state.matchedUsers,
                isLoading: state.isSearchingUsers,
                onUserTap: _openUser,
              ),
            ),
          if (visibleSpots.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final spot = visibleSpots[index];
                    final liveLike = likeOverrides[spot.id];
                    final displaySpot = liveLike == null
                        ? spot
                        : spot.copyWith(likesCount: liveLike.likesCount);
                    return _CompactExploreSpotCard(
                      spot: displaySpot,
                      isLikedOverride: liveLike?.isLiked,
                      onTap: () => _openSpot(spot),
                    );
                  },
                  childCount: visibleSpots.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Center(
                child: state.isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (state.hasMore && visibleSpots.isNotEmpty
                        ? TextButton(
                            key: const Key('explore_load_more_button'),
                            onPressed: () => ref
                                .read(exploreFeedControllerProvider.notifier)
                                .loadMore(),
                            child: const Text('Tải thêm địa điểm'),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({
    required this.selectedCategory,
    required this.selectedPrice,
    required this.selectedBestTime,
    required this.onRemoveCategory,
    required this.onRemovePrice,
    required this.onRemoveTime,
    required this.onClearAll,
  });

  final String? selectedCategory;
  final String? selectedPrice;
  final String? selectedBestTime;
  final VoidCallback onRemoveCategory;
  final VoidCallback onRemovePrice;
  final VoidCallback onRemoveTime;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('explore_active_filter_bar'),
      width: double.infinity,
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (selectedCategory != null)
            InputChip(
              key: const Key('active_category_chip'),
              label: Text(
                selectedCategory!,
                style: const TextStyle(fontSize: 11.5),
              ),
              onDeleted: onRemoveCategory,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (selectedPrice != null)
            InputChip(
              key: const Key('active_price_chip'),
              label: Text(
                selectedPrice!,
                style: const TextStyle(fontSize: 11.5),
              ),
              onDeleted: onRemovePrice,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (selectedBestTime != null)
            InputChip(
              key: const Key('active_time_chip'),
              label: Text(
                selectedBestTime!,
                style: const TextStyle(fontSize: 11.5),
              ),
              onDeleted: onRemoveTime,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          TextButton(
            key: const Key('active_filters_clear_all'),
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Xóa lọc',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchedUsersStrip extends StatelessWidget {
  const _MatchedUsersStrip({
    required this.users,
    required this.isLoading,
    required this.onUserTap,
  });

  final List<ExploreUserHit> users;
  final bool isLoading;
  final ValueChanged<ExploreUserHit> onUserTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản phù hợp',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final avatar = user.avatarUrl.isNotEmpty
                      ? CloudinaryUrlHelper.feedThumbnail(user.avatarUrl)
                      : '';
                  return Material(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('explore_user_hit_${user.uid}'),
                      onTap: () => onUserTap(user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                colors.outlineVariant.withValues(alpha: 0.45),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: avatar.isNotEmpty
                                  ? CachedNetworkImageProvider(avatar)
                                  : null,
                              child: avatar.isEmpty
                                  ? Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user.handle,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactExploreSpotCard extends StatelessWidget {
  const _CompactExploreSpotCard({
    required this.spot,
    required this.onTap,
    this.isLikedOverride,
  });

  final ExploreSpotSummary spot;
  final VoidCallback onTap;
  final bool? isLikedOverride;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thumbUrl = spot.thumbnailUrl.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(spot.thumbnailUrl)
        : '';
    final isHeartFilled = isLikedOverride ?? (spot.likesCount > 0);

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('explore_spot_card_${spot.id}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.42),
              width: 0.7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: colors.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => _SpotCardPlaceholder(
                          colors: colors,
                        ),
                      )
                    : _SpotCardPlaceholder(colors: colors),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spot.category.isNotEmpty)
                      Text(
                        spot.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          height: 1.15,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      spot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (spot.priceTag.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 11.5,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              spot.priceTag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11.5,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ExploreFeedLogic.formatRelativeTime(
                              spot.createdAt,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isHeartFilled
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 13,
                          color: isHeartFilled
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${spot.likesCount}',
                          key: Key('explore_spot_likes_${spot.id}'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${spot.ratingCount}',
                          key: Key('explore_spot_reviews_${spot.id}'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.star_rounded,
                          size: 13.5,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          spot.hasRating
                              ? spot.ratingAvg.toStringAsFixed(1)
                              : '--',
                          key: Key('explore_spot_rating_${spot.id}'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotCardPlaceholder extends StatelessWidget {
  const _SpotCardPlaceholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.landscape_outlined,
        size: 30,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _ExploreLoadingSkeletonGrid extends StatelessWidget {
  const _ExploreLoadingSkeletonGrid({
    required this.crossAxisCount,
    required this.mainAxisExtent,
  });

  final int crossAxisCount;
  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      key: const Key('explore_loading_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ExploreStateMessage extends StatelessWidget {
  const _ExploreStateMessage({
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
                child: Icon(icon, size: 28, color: colors.onSurfaceVariant),
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