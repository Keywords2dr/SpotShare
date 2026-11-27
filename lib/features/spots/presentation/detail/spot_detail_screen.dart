import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../../../core/utils/date_time_helper.dart';
import '../../../profile/data/saved_collections_repository.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../../profile/presentation/saved_collections_controller.dart';
import '../../../profile/presentation/widgets/saved_collections_sheets.dart';
import '../../../social/presentation/social_providers.dart';
import '../../../social/presentation/widgets/review_section.dart';
import '../../domain/spot_model.dart';
import '../../domain/spot_tag_presets.dart';
import '../like/spot_like_controller.dart';
import '../spot_providers.dart';
import '../widgets/spot_tag_selector.dart';
import 'spot_detail_support.dart';
import 'widgets/spot_image_carousel.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({
    super.key,
    required this.spotId,
    this.initialSpot,
    this.initialReviewId,
  });

  final String spotId;
  final SpotModel? initialSpot;
  final String? initialReviewId;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final FocusNode _commentFocusNode = FocusNode();

  bool _isTogglingSave = false;
  bool _isDeletingSpot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = ref.read(spotDetailCurrentUserIdProvider)?.trim() ?? '';
      if (uid.isNotEmpty) {
        ref.read(savedCollectionsControllerProvider.notifier).load(userId: uid);
      }
    });
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    super.dispose();
  }

  SavedSpotItem _toSavedSpotItem(SpotModel spot) {
    return SavedSpotItem(
      id: spot.id,
      title: spot.title,
      category: spot.category,
      thumbnailUrl: spot.imageUrls.isNotEmpty ? spot.imageUrls.first : '',
      authorId: spot.authorId,
      authorName: spot.authorName,
      likesCount: spot.likesCount,
      ratingAvg: spot.ratingAvg,
      ratingCount: spot.ratingCount,
      addressText: spot.addressText,
      priceTag: spot.priceTag,
      bestTimeTag: spot.bestTimeTag,
      latitude: spot.latitude,
      longitude: spot.longitude,
      savedAt: DateTime.now(),
    );
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
      ),
    );
  }

  void _navigateBack() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/explore');
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _refreshSpot() async {
    final userId = ref.read(spotDetailCurrentUserIdProvider) ?? '';
    ref.invalidate(spotDetailProvider(widget.spotId));
    ref.invalidate(spotSavedProvider(widget.spotId));
    if (userId.isNotEmpty) {
      ref.invalidate(
        spotIsLikedStreamProvider((spotId: widget.spotId, userId: userId)),
      );
      ref.read(savedCollectionsControllerProvider.notifier).load(
            userId: userId,
            forceRefresh: true,
          );
    }
    try {
      await ref.read(spotDetailProvider(widget.spotId).future);
    } catch (_) {}
  }

  Future<void> _toggleLike({
    required SpotModel spot,
    required bool currentLiked,
    required int currentLikesCount,
  }) async {
    final userId = ref.read(spotDetailCurrentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để thả tim địa điểm.');
      return;
    }

    final outcome =
        await ref.read(spotLikeControllerProvider.notifier).toggleLike(
              spotId: spot.id,
              userId: userId,
              fallbackIsLiked: currentLiked,
              fallbackLikesCount: currentLikesCount,
              authorId: spot.authorId,
            );

    if (!outcome.success && !outcome.ignored && outcome.errorMessage != null) {
      _showSnackBar(outcome.errorMessage!);
    }
  }

  Future<void> _openCreateCollectionForSpot(
    String userId,
    SpotModel spot,
  ) async {
    if (!mounted) return;
    final created = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionEditorSheet(
        userId: userId,
        initialSpotIds: [spot.id],
        seedSpot: _toSavedSpotItem(spot),
      ),
    );
    if (created is SpotCollectionModel && mounted) {
      _showSnackBar(
        'Đã lưu "${spot.title}" vào bộ sưu tập "${created.name}".',
      );
    }
  }

  Future<void> _openAssignCollections(String userId, SpotModel spot) async {
    if (!mounted) return;
    final selectedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssignSpotToCollectionsSheet(
        userId: userId,
        spotId: spot.id,
        spotTitle: spot.title,
        spotFallback: _toSavedSpotItem(spot),
      ),
    );
    if (selectedCount != null && mounted) {
      if (selectedCount == 0) {
        _showSnackBar('Đã lưu "${spot.title}" vào mục Đã lưu.');
      } else {
        _showSnackBar(
          'Đã lưu "${spot.title}" vào $selectedCount bộ sưu tập đã chọn.',
        );
      }
    }
  }

  Future<void> _toggleSave({
    required SpotModel spot,
    required bool currentSaved,
  }) async {
    if (_isTogglingSave) return;
    final userId = ref.read(spotDetailCurrentUserIdProvider)?.trim() ?? '';
    if (userId.isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để lưu địa điểm.');
      return;
    }

    final savedNotifier =
        ref.read(savedCollectionsControllerProvider.notifier);
    if (!savedNotifier.stateFor(userId).hasLoaded) {
      await savedNotifier.load(userId: userId);
      if (!mounted) return;
    }

    final savedState = savedNotifier.stateFor(userId);
    final containing = savedState.collectionsContainingSpot(spot.id);

    if (!currentSaved) {
      if (savedState.collections.isNotEmpty) {
        final selectedCount = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => AssignSpotToCollectionsSheet(
            userId: userId,
            spotId: spot.id,
            spotTitle: spot.title,
            spotFallback: _toSavedSpotItem(spot),
          ),
        );
        if (!mounted) return;
        if (selectedCount != null && selectedCount > 0) {
          _showSnackBar(
            'Đã lưu "${spot.title}" vào $selectedCount bộ sưu tập đã chọn.',
          );
          return;
        }
        if (selectedCount == 0) {
          _showSnackBar('Đã lưu vào mục Đã lưu.');
          return;
        }
      }

      setState(() => _isTogglingSave = true);
      final res = await savedNotifier.saveSpotToDefault(
        userId: userId,
        spot: _toSavedSpotItem(spot),
      );
      if (!mounted) return;
      setState(() => _isTogglingSave = false);

      if (res.success) {
        _showSnackBar(
          'Đã lưu vào mục Đã lưu.',
          action: SnackBarAction(
            label: savedState.collections.isEmpty
                ? 'Tạo bộ sưu tập'
                : 'Bộ sưu tập',
            onPressed: () {
              if (savedState.collections.isEmpty) {
                _openCreateCollectionForSpot(userId, spot);
              } else {
                _openAssignCollections(userId, spot);
              }
            },
          ),
        );
      } else if (res.errorMessage != null) {
        _showSnackBar(res.errorMessage!);
      }
      return;
    }

    if (containing.length >= 2) {
      final clearedAll = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RemoveSpotFromCollectionsSheet(
          userId: userId,
          spotId: spot.id,
          spotTitle: spot.title,
        ),
      );
      if (clearedAll == true && mounted) {
        _showSnackBar('Đã bỏ lưu hoàn toàn "${spot.title}".');
      }
      return;
    }

    setState(() => _isTogglingSave = true);
    if (containing.length == 1) {
      final onlyCollection = containing.first;
      final res = await savedNotifier.removeSpotFromCollection(
        userId: userId,
        collectionId: onlyCollection.id,
        spotId: spot.id,
      );
      if (!mounted) return;
      setState(() => _isTogglingSave = false);
      if (res.success) {
        _showSnackBar(
          'Đã bỏ lưu hoàn toàn khỏi bộ sưu tập "${onlyCollection.name}".',
        );
      } else if (res.errorMessage != null) {
        _showSnackBar(res.errorMessage!);
      }
      return;
    }

    final res = await savedNotifier.unsaveUncategorizedSpot(
      userId: userId,
      spotId: spot.id,
    );
    if (!mounted) return;
    setState(() => _isTogglingSave = false);
    if (res.success) {
      _showSnackBar('Đã bỏ khỏi mục Đã lưu.');
    } else if (res.errorMessage != null) {
      _showSnackBar(res.errorMessage!);
    }
  }

  Future<void> _copyCoordinates(SpotModel spot) async {
    final coords = SpotCoordinatesHelper.format(spot.latitude, spot.longitude);
    await Clipboard.setData(ClipboardData(text: coords));
    _showSnackBar('Đã sao chép tọa độ: $coords');
  }

  Future<void> _copyMapsLink(SpotModel spot) async {
    final url = SpotCoordinatesHelper.googleMapsUrl(
      spot.latitude,
      spot.longitude,
    );
    await Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('Đã sao chép đường dẫn chỉ đường Google Maps.');
  }

  Future<void> _copyShareSummary(SpotModel spot) async {
    final text = SpotCoordinatesHelper.buildShareSummary(
      title: spot.title,
      category: spot.category,
      addressText: spot.addressText,
      latitude: spot.latitude,
      longitude: spot.longitude,
    );
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Đã sao chép thông tin địa điểm để chia sẻ.');
  }

  Future<void> _openReportSheet(SpotModel spot) async {
    final userId = ref.read(spotDetailCurrentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để báo cáo nội dung vi phạm.');
      return;
    }

    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SpotReportSheet(
        spotId: spot.id,
        spotTitle: spot.title,
        reporterId: userId,
      ),
    );

    if (reported == true) {
      _showSnackBar('Cảm ơn bạn! Báo cáo đã được gửi để kiểm duyệt.');
    }
  }

  Future<void> _confirmAndDeleteSpot(SpotModel spot) async {
    if (_isDeletingSpot) return;
    final userId = ref.read(spotDetailCurrentUserIdProvider);
    if (userId == null || userId != spot.authorId) return;

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
            child: const Text(
              'Xóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingSpot = true);
    try {
      await ref.read(spotRepositoryProvider).deleteSpot(
            spotId: spot.id,
            currentUserId: userId,
          );
      if (!mounted) return;
      _showSnackBar('Đã xóa bài đăng.');
      _navigateBack();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotDetailScreen] deleteSpot failed: $e');
      }
      if (!mounted) return;
      setState(() => _isDeletingSpot = false);
      _showSnackBar(
        SpotDetailErrorMapper.map(
          e,
          fallback: 'Xóa bài đăng thất bại. Vui lòng thử lại.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(spotDetailCurrentUserIdProvider) ?? '';

    ref.listen<AsyncValue<SpotModel?>>(spotDetailProvider(widget.spotId),
        (_, next) {
      final nextSpot = next.value;
      if (nextSpot == null) return;
      final existing = ref.read(spotLikeControllerProvider)[nextSpot.id];
      if (existing == null || existing.isProcessing) return;
      final latestLiked = currentUserId.isEmpty
          ? false
          : (ref
                  .read(
                    spotIsLikedStreamProvider(
                      (spotId: nextSpot.id, userId: currentUserId),
                    ),
                  )
                  .value ??
              existing.isLiked);
      if (latestLiked == existing.isLiked) {
        ref.read(spotLikeControllerProvider.notifier).syncFromServer(
              spotId: nextSpot.id,
              isLiked: latestLiked,
              likesCount: nextSpot.likesCount,
            );
      }
    });

    final spotAsync = ref.watch(spotDetailProvider(widget.spotId));
    final spot = spotAsync.value ?? widget.initialSpot;

    if (spotAsync.isLoading && spot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (spot == null && spotAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: SpotDetailErrorView(
          icon: Icons.wifi_off_rounded,
          title: 'Không thể tải địa điểm',
          message: SpotDetailErrorMapper.map(
            spotAsync.error!,
            fallback: 'Không thể tải thông tin địa điểm lúc này. Vui lòng thử lại.',
          ),
          onRetry: _refreshSpot,
          onBack: _navigateBack,
        ),
      );
    }

    if (spot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: SpotDetailErrorView(
          icon: Icons.location_off_outlined,
          title: 'Không tìm thấy địa điểm',
          message:
              'Địa điểm này có thể đã bị tác giả xóa hoặc liên kết không còn hợp lệ.',
          onBack: _navigateBack,
        ),
      );
    }

    final isOwner = currentUserId.isNotEmpty && currentUserId == spot.authorId;

    final serverLiked = currentUserId.isEmpty
        ? false
        : (ref
                .watch(
                  spotIsLikedStreamProvider(
                    (spotId: spot.id, userId: currentUserId),
                  ),
                )
                .value ??
            false);
    final likeOverride = ref.watch(
      spotLikeControllerProvider.select((map) => map[spot.id]),
    );
    final displayLiked = likeOverride?.isLiked ?? serverLiked;
    final displayLikesCount = likeOverride?.likesCount ??
        (spot.likesCount < 0 ? 0 : spot.likesCount);
    final isLikeProcessing = likeOverride?.isProcessing ?? false;

    final serverDefaultSaved =
        ref.watch(spotSavedProvider(spot.id)).value ?? false;
    final savedViewState = currentUserId.isEmpty
        ? const SavedCollectionsViewState()
        : ref.watch(
            savedCollectionsControllerProvider.select(
              (map) => map[currentUserId] ?? const SavedCollectionsViewState(),
            ),
          );
    final displaySaved = savedViewState.hasLoaded
        ? savedViewState.isSpotSavedAnywhere(spot.id)
        : (serverDefaultSaved || savedViewState.isSpotInAnyCollection(spot.id));

    final liveAuthorAvatar =
        ref.watch(userAvatarProvider(spot.authorId)).value ?? '';
    final rawAuthorAvatar =
        liveAuthorAvatar.isNotEmpty ? liveAuthorAvatar : spot.authorAvatar;
    final authorAvatarUrl = rawAuthorAvatar.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(rawAuthorAvatar)
        : '';

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final transportTags = SpotTagPresets.parseMultiTag(spot.difficultyTag);
    final quickTags = <SpotQuickTagData>[
      if (spot.bestTimeTag.isNotEmpty)
        SpotQuickTagData(
          icon: Icons.wb_sunny_outlined,
          label: spot.bestTimeTag,
        ),
      for (final transport in transportTags)
        SpotQuickTagData(
          icon: transportIconFor(transport),
          label: transport,
        ),
      if (spot.priceTag.isNotEmpty)
        SpotQuickTagData(
          icon: Icons.payments_outlined,
          label: spot.priceTag,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 60,
        title: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: spot.authorId.isNotEmpty
              ? () => context.push('/users/${spot.authorId}')
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: authorAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(authorAvatarUrl)
                      : null,
                  onBackgroundImageError:
                      authorAvatarUrl.isNotEmpty ? (_, _) {} : null,
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
          ),
        ),
        actions: [
          if (_isDeletingSpot)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: colors.onSurface,
              ),
              tooltip: 'Tùy chọn bài viết',
              onSelected: (value) {
                if (value == 'share') {
                  _copyShareSummary(spot);
                } else if (value == 'collection' && currentUserId.isNotEmpty) {
                  _openAssignCollections(currentUserId, spot);
                } else if (value == 'edit') {
                  context.push('/spots/${spot.id}/edit', extra: spot);
                } else if (value == 'delete') {
                  _confirmAndDeleteSpot(spot);
                } else if (value == 'report') {
                  _openReportSheet(spot);
                }
              },
              itemBuilder: (context) => [
                if (currentUserId.isNotEmpty)
                  const PopupMenuItem<String>(
                    value: 'collection',
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder_outlined, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Chọn bộ sưu tập',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Sao chép chia sẻ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (isOwner) ...[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Chỉnh sửa bài viết',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
                          size: 20,
                          color: colors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Xóa bài viết',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 20,
                          color: colors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Báo cáo vi phạm',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
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
          if (spotAsync.hasError)
            Material(
              color: colors.errorContainer.withValues(alpha: 0.72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: colors.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang hiển thị dữ liệu đã lưu tạm. Chạm Thử lại để đồng bộ.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _refreshSpot,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onErrorContainer,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshSpot,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                color:
                                    colors.onSurface.withValues(alpha: 0.88),
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
                    SpotActionBar(
                      isLiked: displayLiked,
                      likesCount: displayLikesCount,
                      isSaved: displaySaved,
                      ratingAvg: spot.ratingAvg,
                      ratingCount: spot.ratingCount,
                      isLikeDisabled: isLikeProcessing,
                      isSaveDisabled: _isTogglingSave,
                      onLikeTap: () => _toggleLike(
                        spot: spot,
                        currentLiked: displayLiked,
                        currentLikesCount: displayLikesCount,
                      ),
                      onCommentTap: () => _commentFocusNode.requestFocus(),
                      onSaveTap: () => _toggleSave(
                        spot: spot,
                        currentSaved: displaySaved,
                      ),
                    ),
                    SpotCoordinatesCard(
                      tags: quickTags,
                      latitude: spot.latitude,
                      longitude: spot.longitude,
                      onCopyCoordinates: () => _copyCoordinates(spot),
                      onCopyMapsLink: () => _copyMapsLink(spot),
                    ),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.45),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: ReviewSection(
                        spot: spot,
                        initialReviewId: widget.initialReviewId,
                      ),
                    ),
                  ],
                ),
              ),
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