import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../data/saved_collections_repository.dart';
import '../saved_collections_controller.dart';
import 'saved_collections_sheets.dart';

class SavedCollectionsTab extends ConsumerStatefulWidget {
  const SavedCollectionsTab({
    super.key,
    required this.userId,
    this.onSpotTap,
    this.onExploreTap,
  });

  final String userId;
  final void Function(SavedSpotItem spot)? onSpotTap;
  final VoidCallback? onExploreTap;

  @override
  ConsumerState<SavedCollectionsTab> createState() =>
      _SavedCollectionsTabState();
}

class _SavedCollectionsTabState extends ConsumerState<SavedCollectionsTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(savedCollectionsControllerProvider.notifier).load(
            userId: widget.userId,
            cleanupOrphans: true,
          );
    });
  }

  @override
  void didUpdateWidget(covariant SavedCollectionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(savedCollectionsControllerProvider.notifier).load(
              userId: widget.userId,
              cleanupOrphans: true,
            );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() {
    return ref.read(savedCollectionsControllerProvider.notifier).load(
          userId: widget.userId,
          forceRefresh: true,
          cleanupOrphans: true,
        );
  }

  Future<void> _openSpot(SavedSpotItem spot) async {
    if (widget.onSpotTap != null) {
      widget.onSpotTap!(spot);
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      await router.push('/spots/${spot.id}');
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
    GoRouter.maybeOf(context)?.go('/explore');
  }

  Future<void> _openCreateCollection() async {
    final created = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionEditorSheet(userId: widget.userId),
    );
    if (created != null && mounted) {
      _showSnackBar('Đã tạo bộ sưu tập mới.');
    }
  }

  Future<void> _openEditCollection(SpotCollectionModel collection) async {
    final updated = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionEditorSheet(
        userId: widget.userId,
        existingCollection: collection,
      ),
    );
    if (updated != null && mounted) {
      _showSnackBar('Đã cập nhật bộ sưu tập.');
    }
  }

  Future<void> _openManageCollectionSpots(SpotCollectionModel collection) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManageCollectionSpotsSheet(
        userId: widget.userId,
        collection: collection,
      ),
    );
    if (updated == true && mounted) {
      _showSnackBar('Đã cập nhật địa điểm trong bộ sưu tập.');
    }
  }

  Future<void> _confirmDeleteCollection(SpotCollectionModel collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteCollectionDialog(collectionName: collection.name),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .deleteCollection(
          userId: widget.userId,
          collectionId: collection.id,
        );
    if (!mounted) return;
    if (result.success) {
      _showSnackBar(
        'Đã xóa bộ sưu tập "${collection.name}" và toàn bộ địa điểm bên trong.',
      );
    } else if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!);
    }
  }

  Future<void> _openAssignCollections(SavedSpotItem spot) async {
    final selectedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssignSpotToCollectionsSheet(
        userId: widget.userId,
        spotId: spot.id,
        spotTitle: spot.title,
        spotFallback: spot,
      ),
    );
    if (selectedCount != null && mounted) {
      if (selectedCount == 0) {
        _showSnackBar(
          'Giữ "${spot.title}" ở mục Đã lưu (không thuộc bộ sưu tập nào).',
        );
      } else {
        _showSnackBar(
          'Đã cập nhật "${spot.title}" vào $selectedCount bộ sưu tập.',
        );
      }
    }
  }

  Future<void> _unsaveSpot(SavedSpotItem spot) async {
    final viewState = ref
        .read(savedCollectionsControllerProvider.notifier)
        .stateFor(widget.userId);
    final containingCols = viewState.collectionsContainingSpot(spot.id);

    if (containingCols.isNotEmpty) {
      final colors = Theme.of(context).colorScheme;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bỏ lưu địa điểm'),
          content: Text(
            '"${spot.title}" đang nằm trong ${containingCols.length} bộ sưu tập. Bỏ lưu sẽ xóa hoàn toàn địa điểm này khỏi mục Đã lưu và tất cả bộ sưu tập đó. Bạn có chắc muốn tiếp tục không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Xóa hết',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .unsaveUncategorizedSpot(
          userId: widget.userId,
          spotId: spot.id,
        );
    if (!mounted) return;
    if (result.success) {
      _showSnackBar(
        'Đã xóa "${spot.title}" khỏi mục Đã lưu và tất cả bộ sưu tập.',
      );
    } else if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!);
    }
  }

  Future<void> _openCollectionDetail(SpotCollectionModel collection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionDetailScreen(
          userId: widget.userId,
          collectionId: collection.id,
          onSpotTap: widget.onSpotTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewState = ref.watch(
      savedCollectionsControllerProvider.select(
        (map) => map[widget.userId] ?? const SavedCollectionsViewState(),
      ),
    );
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        _SavedSubNavBar(
          spotsCount: viewState.savedSpots.length,
          collectionsCount: viewState.collections.length,
          activeTab: viewState.activeSubTab,
          isSearchOpen: viewState.isSearchOpen,
          onSelectTab: (tab) => ref
              .read(savedCollectionsControllerProvider.notifier)
              .setSubTab(widget.userId, tab),
          onToggleSearch: () {
            if (viewState.isSearchOpen) {
              _searchController.clear();
            }
            ref
                .read(savedCollectionsControllerProvider.notifier)
                .toggleSearch(widget.userId);
          },
        ),
        if (viewState.isSearchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                key: const Key('saved_search_field'),
                controller: _searchController,
                onChanged: (value) => ref
                    .read(savedCollectionsControllerProvider.notifier)
                    .setSearchQuery(widget.userId, value),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.65),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17),
                  suffixIcon: viewState.searchQuery.isNotEmpty
                      ? IconButton(
                          key: const Key('saved_search_clear'),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(
                                  savedCollectionsControllerProvider.notifier,
                                )
                                .setSearchQuery(widget.userId, '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                        )
                      : null,
                  hintText: viewState.activeSubTab == SavedSubTab.allSpots
                      ? 'Tìm trong tất cả bài đã lưu...'
                      : 'Tìm tên bộ sưu tập hoặc địa điểm...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        Divider(
          height: 0.6,
          thickness: 0.6,
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
        Expanded(
          child: _buildBody(context, viewState),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    SavedCollectionsViewState viewState,
  ) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final spotExtent = SavedCollectionsLogic.resolveSavedCardExtent(textScale);
    final colExtent =
        SavedCollectionsLogic.resolveCollectionCardExtent(textScale);

    if (viewState.isInitialLoading ||
        (!viewState.hasLoaded && !viewState.isLoading)) {
      return _SavedLoadingGrid(mainAxisExtent: spotExtent);
    }

    if (viewState.errorMessage != null &&
        viewState.savedSpots.isEmpty &&
        viewState.collections.isEmpty) {
      return _SavedMessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Không thể tải mục Đã lưu',
        message: viewState.errorMessage!,
        actionLabel: 'Thử lại',
        actionKey: const Key('saved_retry_button'),
        onAction: _refresh,
      );
    }

    if (viewState.activeSubTab == SavedSubTab.allSpots) {
      final spots = viewState.filteredSpots;
      if (spots.isEmpty) {
        if (viewState.searchQuery.trim().isNotEmpty) {
          return _SavedMessageState(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy địa điểm khớp',
            message: 'Thử từ khóa khác hoặc xóa bộ lọc tìm kiếm.',
            actionLabel: 'Xóa tìm kiếm',
            actionKey: const Key('saved_clear_search_empty'),
            onAction: () {
              _searchController.clear();
              ref
                  .read(savedCollectionsControllerProvider.notifier)
                  .setSearchQuery(widget.userId, '');
            },
          );
        }
        return _SavedMessageState(
          icon: Icons.bookmark_border_rounded,
          title: 'Chưa có bài đăng đã lưu',
          message:
              'Tất cả bài đăng bạn đã lưu (bao gồm cả các bài trong bộ sưu tập) sẽ hiển thị tại đây.',
          actionLabel: 'Khám phá ngay',
          actionKey: const Key('saved_explore_cta'),
          onAction: _openExplore,
        );
      }

      return RefreshIndicator(
        onRefresh: _refresh,
        child: GridView.builder(
          key: const Key('saved_spots_grid'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: spotExtent,
          ),
          itemCount: spots.length,
          itemBuilder: (context, index) {
            final spot = spots[index];
            final collectionCount = SavedCollectionsLogic.countCollectionsForSpot(
              spotId: spot.id,
              collections: viewState.collections,
            );
            return _SavedSpotCard(
              spot: spot,
              collectionCount: collectionCount,
              onTap: () => _openSpot(spot),
              onAssignTap: () => _openAssignCollections(spot),
              onUnsaveTap: () => _unsaveSpot(spot),
            );
          },
        ),
      );
    }

    final collections = viewState.filteredCollections;
    final spotMap = viewState.spotById;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        key: const Key('saved_collections_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: OutlinedButton.icon(
                key: const Key('create_collection_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _openCreateCollection,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text(
                  'Tạo bộ sưu tập mới',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          if (collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _SavedMessageState(
                icon: viewState.searchQuery.trim().isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.folder_special_outlined,
                title: viewState.searchQuery.trim().isNotEmpty
                    ? 'Không tìm thấy bộ sưu tập'
                    : 'Chưa có bộ sưu tập nào',
                message: viewState.searchQuery.trim().isNotEmpty
                    ? 'Không có bộ sưu tập nào khớp với từ khóa hiện tại.'
                    : 'Tạo danh mục riêng như "Du lịch cuối tuần", "Quán ngon nhất định thử" để phân loại địa điểm theo ý bạn.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: colExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final collection = collections[index];
                    final coverUrls =
                        SavedCollectionsLogic.resolveCoverThumbnails(
                      collection: collection,
                      spotMap: spotMap,
                    );
                    return _CollectionFolderCard(
                      collection: collection,
                      coverUrls: coverUrls,
                      onTap: () => _openCollectionDetail(collection),
                      onEdit: () => _openEditCollection(collection),
                      onManageSpots: () =>
                          _openManageCollectionSpots(collection),
                      onDelete: () => _confirmDeleteCollection(collection),
                    );
                  },
                  childCount: collections.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedSubNavBar extends StatelessWidget {
  const _SavedSubNavBar({
    required this.spotsCount,
    required this.collectionsCount,
    required this.activeTab,
    required this.isSearchOpen,
    required this.onSelectTab,
    required this.onToggleSearch,
  });

  final int spotsCount;
  final int collectionsCount;
  final SavedSubTab activeTab;
  final bool isSearchOpen;
  final ValueChanged<SavedSubTab> onSelectTab;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SubTabLabel(
                    key: const Key('saved_subtab_all_spots'),
                    label: 'Đã lưu $spotsCount',
                    isSelected: activeTab == SavedSubTab.allSpots,
                    onTap: () => onSelectTab(SavedSubTab.allSpots),
                  ),
                  const SizedBox(width: 14),
                  _SubTabLabel(
                    key: const Key('saved_subtab_collections'),
                    label: 'Bộ sưu tập $collectionsCount',
                    isSelected: activeTab == SavedSubTab.collections,
                    onTap: () => onSelectTab(SavedSubTab.collections),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('saved_subtab_search_toggle'),
            tooltip: isSearchOpen ? 'Đóng tìm kiếm' : 'Tìm trong mục Đã lưu',
            onPressed: onToggleSearch,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            icon: Icon(
              isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
              size: 19,
              color: isSearchOpen ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTabLabel extends StatelessWidget {
  const _SubTabLabel({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SavedSpotCard extends StatelessWidget {
  const _SavedSpotCard({
    required this.spot,
    this.collectionCount = 0,
    required this.onTap,
    required this.onAssignTap,
    required this.onUnsaveTap,
  });

  final SavedSpotItem spot;
  final int collectionCount;
  final VoidCallback onTap;
  final VoidCallback onAssignTap;
  final VoidCallback onUnsaveTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thumbUrl = spot.thumbnailUrl.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(spot.thumbnailUrl)
        : '';

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('saved_spot_card_${spot.id}'),
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
                        errorWidget: (_, _, _) => Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.landscape_outlined,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.landscape_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: colors.surface.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: PopupMenuButton<String>(
                          key: Key('saved_spot_menu_${spot.id}'),
                          tooltip: 'Tùy chọn địa điểm đã lưu',
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'assign') {
                              onAssignTap();
                            } else if (value == 'unsave') {
                              onUnsaveTap();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem<String>(
                              value: 'assign',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.create_new_folder_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    collectionCount > 0
                                        ? 'Chỉnh sửa bộ sưu tập'
                                        : 'Thêm vào bộ sưu tập',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'unsave',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_remove_outlined,
                                    size: 18,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Bỏ lưu',
                                    style: TextStyle(
                                      color: colors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(Icons.more_horiz_rounded, size: 17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                    const SizedBox(height: 5),
                    Row(
                      children: [
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
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              key: Key('saved_spot_assign_chip_${spot.id}'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: onAssignTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      collectionCount > 0
                                          ? Icons.folder_rounded
                                          : Icons.folder_outlined,
                                      size: 12.5,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        collectionCount > 0
                                            ? '$collectionCount bộ'
                                            : 'Phân loại',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

class _CollectionFolderCard extends StatelessWidget {
  const _CollectionFolderCard({
    required this.collection,
    required this.coverUrls,
    required this.onTap,
    required this.onEdit,
    required this.onManageSpots,
    required this.onDelete,
  });

  final SpotCollectionModel collection;
  final List<String> coverUrls;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onManageSpots;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('collection_card_${collection.id}'),
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CollectionCoverCollage(
                      urls: coverUrls,
                      iconKey: collection.iconKey,
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: colors.surface.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: PopupMenuButton<String>(
                          key: Key('collection_menu_${collection.id}'),
                          tooltip: 'Tùy chọn bộ sưu tập',
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'manage') {
                              onManageSpots();
                            } else if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem<String>(
                              value: 'manage',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Thêm / bớt địa điểm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sửa bộ sưu tập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Xóa bộ sưu tập',
                                    style: TextStyle(
                                      color: colors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(Icons.more_horiz_rounded, size: 17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          collectionIconFor(collection.iconKey),
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            collection.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${collection.spotIds.length} địa điểm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.onSurfaceVariant,
                      ),
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

class _CollectionCoverCollage extends StatelessWidget {
  const _CollectionCoverCollage({
    required this.urls,
    required this.iconKey,
  });

  final List<String> urls;
  final String iconKey;

  Widget _tile(BuildContext context, String rawUrl) {
    final colors = Theme.of(context).colorScheme;
    final url = CloudinaryUrlHelper.feedThumbnail(rawUrl);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: colors.surfaceContainerHighest),
      errorWidget: (_, _, _) => Container(
        color: colors.surfaceContainerHighest,
        child: Icon(
          Icons.landscape_outlined,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (urls.isEmpty) {
      return Container(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: Icon(
          collectionIconFor(iconKey),
          size: 34,
          color: colors.primary.withValues(alpha: 0.75),
        ),
      );
    }
    if (urls.length == 1) {
      return _tile(context, urls[0]);
    }
    if (urls.length == 2) {
      return Row(
        children: [
          Expanded(child: _tile(context, urls[0])),
          const SizedBox(width: 1.5),
          Expanded(child: _tile(context, urls[1])),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(context, urls[0])),
              const SizedBox(width: 1.5),
              Expanded(child: _tile(context, urls[1])),
            ],
          ),
        ),
        const SizedBox(height: 1.5),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(context, urls[2])),
              const SizedBox(width: 1.5),
              Expanded(
                child: urls.length >= 4
                    ? _tile(context, urls[3])
                    : Container(
                        color: colors.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          collectionIconFor(iconKey),
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedLoadingGrid extends StatelessWidget {
  const _SavedLoadingGrid({required this.mainAxisExtent});

  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      key: const Key('saved_loading_grid'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _SavedMessageState extends StatelessWidget {
  const _SavedMessageState({
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
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
                const SizedBox(height: 14),
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