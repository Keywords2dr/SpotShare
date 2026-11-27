import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../../spots/domain/spot_model.dart';
import '../../data/spot_review_repository.dart';
import '../spot_review_controller.dart';

class ReviewDeepLinkLogic {
  static String? findThreadRootId({
    required ReviewTreeNodeList trees,
    required String reviewId,
  }) {
    final cleanId = reviewId.trim();
    if (cleanId.isEmpty) return null;

    bool containsInNode(SpotReviewTreeNode node) {
      if (node.item.id == cleanId) return true;
      for (final child in node.children) {
        if (containsInNode(child)) return true;
      }
      return false;
    }

    for (final root in trees) {
      if (containsInNode(root)) {
        return root.item.id;
      }
    }
    return null;
  }

  static double highlightOpacity(double progress) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0.65) return 1.0;
    return ((1.0 - t) / 0.35).clamp(0.0, 1.0);
  }
}

class _ThreadTreeMetrics {
  static double avatarRadius(int depth) {
    if (depth <= 0) return 15.0;
    if (depth == 1) return 12.5;
    return 11.0;
  }

  static double indent(int depth) {
    if (depth <= 0) return 0.0;
    if (depth == 1) return 32.0;
    return 60.0;
  }

  static double topPadding(int depth) {
    return depth <= 0 ? 2.0 : 6.0;
  }

  static double spineX(int depth) {
    return indent(depth) + avatarRadius(depth);
  }

  static double avatarCenterY(int depth) {
    return topPadding(depth) + avatarRadius(depth);
  }

  static double avatarBottomY(int depth) {
    return topPadding(depth) + (avatarRadius(depth) * 2);
  }
}

class _ThreadConnectorPainter extends CustomPainter {
  const _ThreadConnectorPainter({
    required this.depth,
    required this.ancestorSpines,
    required this.hasNextSibling,
    required this.hasVisibleChildren,
    required this.lineColor,
    this.customElbowY,
    this.customTargetX,
  });

  final int depth;
  final List<bool> ancestorSpines;
  final bool hasNextSibling;
  final bool hasVisibleChildren;
  final Color lineColor;
  final double? customElbowY;
  final double? customTargetX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < ancestorSpines.length; i++) {
      if (!ancestorSpines[i]) continue;
      final x = _ThreadTreeMetrics.spineX(i);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    if (depth > 0) {
      final parentX = _ThreadTreeMetrics.spineX(depth - 1);
      final targetX =
          customTargetX ?? (_ThreadTreeMetrics.indent(depth) - 3.0);
      final elbowY = customElbowY ?? _ThreadTreeMetrics.avatarCenterY(depth);
      final spanX = math.max(4.0, targetX - parentX);
      final radius = math.min(10.0, math.min(spanX, math.max(4.0, elbowY)));

      final path = Path()
        ..moveTo(parentX, 0)
        ..lineTo(parentX, elbowY - radius)
        ..quadraticBezierTo(parentX, elbowY, parentX + radius, elbowY)
        ..lineTo(targetX, elbowY);
      canvas.drawPath(path, paint);

      if (hasNextSibling) {
        canvas.drawLine(
          Offset(parentX, math.max(0.0, elbowY - radius)),
          Offset(parentX, size.height),
          paint,
        );
      }
    }

    if (hasVisibleChildren && depth < SpotReviewLogic.maxVisualDepth) {
      final ownX = _ThreadTreeMetrics.spineX(depth);
      final startY = _ThreadTreeMetrics.avatarBottomY(depth) + 3.0;
      if (startY < size.height) {
        canvas.drawLine(
          Offset(ownX, startY),
          Offset(ownX, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadConnectorPainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.hasNextSibling != hasNextSibling ||
        oldDelegate.hasVisibleChildren != hasVisibleChildren ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.customElbowY != customElbowY ||
        oldDelegate.customTargetX != customTargetX ||
        !_listEquals(oldDelegate.ancestorSpines, ancestorSpines);
  }

  bool _listEquals(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ReviewSection extends ConsumerStatefulWidget {
  const ReviewSection({
    super.key,
    this.spot,
    this.spotId,
    this.spotAuthorId,
    this.initialReviewId,
    this.onUserTap,
  }) : assert(spot != null || spotId != null);

  final SpotModel? spot;
  final String? spotId;
  final String? spotAuthorId;
  final String? initialReviewId;
  final void Function(String userId)? onUserTap;

  @override
  ConsumerState<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<ReviewSection>
    with SingleTickerProviderStateMixin {
  static const int _collapsedReplyRowLimit = 3;

  final Set<String> _expandedThreadIds = <String>{};
  final GlobalKey _sectionHeaderKey = GlobalKey();
  final GlobalKey _targetReviewKey = GlobalKey();

  late final AnimationController _highlightController;
  String? _highlightedReviewId;
  bool _hasFocusedTarget = false;
  bool _isFocusScheduled = false;
  bool _hasNotifiedMissing = false;

  String get _spotId => (widget.spot?.id ?? widget.spotId ?? '').trim();
  String get _spotAuthorId =>
      (widget.spot?.authorId ?? widget.spotAuthorId ?? '').trim();
  String get _targetReviewId => (widget.initialReviewId ?? '').trim();

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _highlightedReviewId = null;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant ReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSpotId = (oldWidget.spot?.id ?? oldWidget.spotId ?? '').trim();
    final oldTargetId = (oldWidget.initialReviewId ?? '').trim();
    if (oldSpotId != _spotId || oldTargetId != _targetReviewId) {
      _hasFocusedTarget = false;
      _isFocusScheduled = false;
      _hasNotifiedMissing = false;
      _highlightedReviewId = null;
      _highlightController.reset();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  void _scheduleTargetFocus(ReviewTreeNodeList trees) {
    final targetId = _targetReviewId;
    if (targetId.isEmpty || _hasFocusedTarget || _isFocusScheduled) {
      return;
    }

    final rootId = ReviewDeepLinkLogic.findThreadRootId(
      trees: trees,
      reviewId: targetId,
    );

    if (rootId == null) {
      if (_hasNotifiedMissing) return;
      _hasNotifiedMissing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasFocusedTarget) return;
        final headerContext = _sectionHeaderKey.currentContext;
        if (headerContext != null) {
          Scrollable.ensureVisible(
            headerContext,
            alignment: 0.08,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        _showSnackBar('Bình luận này không còn tồn tại.');
      });
      return;
    }

    _isFocusScheduled = true;
    _hasFocusedTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasNotifiedMissing) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      setState(() {
        if (rootId != targetId) {
          _expandedThreadIds.add(rootId);
        }
        _highlightedReviewId = targetId;
      });
      _highlightController.forward(from: 0.0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetContext = _targetReviewKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.25,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _openUserProfile(String userId) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;
    if (widget.onUserTap != null) {
      widget.onUserTap!(cleanUid);
      return;
    }
    final router = GoRouter.maybeOf(context);
    router?.push('/users/$cleanUid');
  }

  void _handleReply(SpotReviewItem target) {
    final currentUserId = ref.read(spotReviewCurrentUserIdProvider);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để trả lời bình luận.');
      return;
    }
    if (!_expandedThreadIds.contains(target.threadRootId)) {
      setState(() {
        _expandedThreadIds.add(target.threadRootId);
      });
    }
    ref.read(spotReviewControllerProvider.notifier).startReply(
          spotId: _spotId,
          target: target,
        );
  }

  Future<void> _handleEdit(SpotReviewItem target) async {
    final currentUserId = ref.read(spotReviewCurrentUserIdProvider);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để chỉnh sửa bình luận.');
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditReviewSheet(
        review: target,
        currentUserId: currentUserId,
      ),
    );

    if (updated == true) {
      _showSnackBar('Đã cập nhật bình luận.');
    }
  }

  Future<void> _handleDelete(SpotReviewItem target) async {
    final currentUserId = ref.read(spotReviewCurrentUserIdProvider);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      _showSnackBar('Vui lòng đăng nhập để xóa bình luận.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteReviewDialog(isReply: target.isReply),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(spotReviewControllerProvider.notifier)
        .deleteReview(target: target, currentUserId: currentUserId);

    if (result.success) {
      _showSnackBar(
        target.isReply ? 'Đã xóa phản hồi.' : 'Đã xóa bình luận.',
      );
    } else if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!);
    }
  }

  Widget _buildRowWidget({
    required SpotReviewDisplayRow row,
    required Color connectorColor,
    required String currentUserId,
    required String? activeReplyTargetId,
    required bool attachTargetKey,
  }) {
    final item = row.item;
    final isFocusedTarget = _highlightedReviewId == item.id;

    Widget buildTile(double focusStrength) {
      final tile = _ThreadedCommentRow(
        row: row,
        connectorColor: connectorColor,
        isHighlighted: activeReplyTargetId == item.id,
        focusHighlightStrength: focusStrength,
        isOwnComment:
            currentUserId.isNotEmpty && currentUserId == item.userId,
        isSpotAuthor:
            _spotAuthorId.isNotEmpty && _spotAuthorId == item.userId,
        onAuthorTap: () => _openUserProfile(item.userId),
        onReplyTap: () => _handleReply(item),
        onEditTap: () => _handleEdit(item),
        onDeleteTap: () => _handleDelete(item),
      );
      if (focusStrength > 0) {
        return KeyedSubtree(
          key: Key('review_focused_highlight_${item.id}'),
          child: tile,
        );
      }
      return tile;
    }

    Widget content;
    if (isFocusedTarget) {
      content = AnimatedBuilder(
        animation: _highlightController,
        builder: (_, _) => buildTile(
          ReviewDeepLinkLogic.highlightOpacity(_highlightController.value),
        ),
      );
    } else {
      content = buildTile(0.0);
    }

    if (attachTargetKey) {
      return KeyedSubtree(
        key: _targetReviewKey,
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(spotReviewsStreamProvider(_spotId));
    final currentUserId = ref.watch(spotReviewCurrentUserIdProvider) ?? '';
    final activeReplyTargetId = ref.watch(
      spotReviewControllerProvider.select(
        (map) => map[_spotId]?.replyingTo?.id,
      ),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final connectorColor = colors.outlineVariant.withValues(alpha: 0.85);

    return reviewsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            key: Key('review_section_loading'),
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => Container(
        key: const Key('review_section_error'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              SpotReviewErrorMapper.map(
                error,
                fallback: 'Không thể tải danh sách bình luận.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const Key('review_section_retry_button'),
              onPressed: () =>
                  ref.invalidate(spotReviewsStreamProvider(_spotId)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (items) {
        final trees = SpotReviewLogic.buildTreeNodes(items);
        final activeCount = SpotReviewLogic.countActiveComments(trees);
        _scheduleTargetFocus(trees);
        var attachedTargetKey = false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: _sectionHeaderKey,
              children: [
                Text(
                  'Bình luận',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  key: const Key('review_section_count'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trees.isEmpty)
              Container(
                key: const Key('review_section_empty'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                    width: 0.7,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 26,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chưa có bình luận nào',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hãy chia sẻ trải nghiệm thực tế của bạn về địa điểm này nhé.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trees.length,
                separatorBuilder: (_, _) => Divider(
                  height: 18,
                  thickness: 0.5,
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final rootNode = trees[index];
                  final isExpanded =
                      _expandedThreadIds.contains(rootNode.item.id);
                  final threadView = SpotReviewLogic.buildThreadView(
                    rootNode: rootNode,
                    isExpanded: isExpanded,
                    collapsedReplyRowLimit: _collapsedReplyRowLimit,
                  );
                  final showToggleRow =
                      rootNode.totalDescendantCount > _collapsedReplyRowLimit;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final row in threadView.visibleRows)
                        Builder(
                          builder: (_) {
                            final shouldAttach = !attachedTargetKey &&
                                _targetReviewId.isNotEmpty &&
                                row.item.id == _targetReviewId;
                            if (shouldAttach) {
                              attachedTargetKey = true;
                            }
                            return _buildRowWidget(
                              row: row,
                              connectorColor: connectorColor,
                              currentUserId: currentUserId,
                              activeReplyTargetId: activeReplyTargetId,
                              attachTargetKey: shouldAttach,
                            );
                          },
                        ),
                      if (showToggleRow)
                        _ThreadToggleRow(
                          rootId: rootNode.item.id,
                          isExpanded: isExpanded,
                          hiddenCount: threadView.hiddenReplyCount,
                          connectorColor: connectorColor,
                          onToggle: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedThreadIds.remove(rootNode.item.id);
                              } else {
                                _expandedThreadIds.add(rootNode.item.id);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ThreadedCommentRow extends StatelessWidget {
  const _ThreadedCommentRow({
    required this.row,
    required this.connectorColor,
    required this.isHighlighted,
    this.focusHighlightStrength = 0.0,
    required this.isOwnComment,
    required this.isSpotAuthor,
    required this.onAuthorTap,
    required this.onReplyTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final SpotReviewDisplayRow row;
  final Color connectorColor;
  final bool isHighlighted;
  final double focusHighlightStrength;
  final bool isOwnComment;
  final bool isSpotAuthor;
  final VoidCallback onAuthorTap;
  final VoidCallback onReplyTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final depth = row.depth;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatarRadius = _ThreadTreeMetrics.avatarRadius(depth);
    final indent = _ThreadTreeMetrics.indent(depth);
    final topPad = _ThreadTreeMetrics.topPadding(depth);
    final avatarUrl = item.userAvatar.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(item.userAvatar)
        : '';

    final double highlightFactor = isHighlighted
        ? 1.0
        : focusHighlightStrength.clamp(0.0, 1.0);
    final baseBubbleColor = depth == 0
        ? colors.surfaceContainerLow
        : colors.surfaceContainerHighest.withValues(alpha: 0.45);
    final highlightBubbleColor =
        colors.primaryContainer.withValues(alpha: 0.5);
    final bubbleColor =
        Color.lerp(baseBubbleColor, highlightBubbleColor, highlightFactor) ??
            baseBubbleColor;

    final baseBorderColor = colors.outlineVariant.withValues(alpha: 0.32);
    final highlightBorderColor = colors.primary.withValues(alpha: 0.72);
    final bubbleBorderColor =
        Color.lerp(baseBorderColor, highlightBorderColor, highlightFactor) ??
            baseBorderColor;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ThreadConnectorPainter(
                depth: depth,
                ancestorSpines: row.ancestorSpines,
                hasNextSibling: row.hasNextSibling,
                hasVisibleChildren: row.hasVisibleChildren,
                lineColor: connectorColor,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(indent, topPad, 0, 6),
          child: Row(
            key: Key('review_tile_${item.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: item.isDeleted ? null : onAuthorTap,
                child: CircleAvatar(
                  key: Key('review_avatar_${item.id}'),
                  radius: avatarRadius,
                  backgroundColor: colors.surfaceContainerHighest,
                  backgroundImage: (!item.isDeleted && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  onBackgroundImageError:
                      (!item.isDeleted && avatarUrl.isNotEmpty)
                          ? (_, _) {}
                          : null,
                  child: (item.isDeleted || avatarUrl.isEmpty)
                      ? Icon(
                          item.isDeleted
                              ? Icons.person_off_outlined
                              : Icons.person_outline_rounded,
                          size: depth == 0 ? 16 : (depth == 1 ? 14 : 13),
                          color: colors.onSurfaceVariant,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: focusHighlightStrength > 0
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      padding: EdgeInsets.symmetric(
                        horizontal: depth == 2 ? 9 : 10,
                        vertical: depth == 2 ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: bubbleBorderColor,
                          width: highlightFactor > 0.05 ? 1.2 : 0.6,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 19),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 5,
                                    runSpacing: 2,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: item.isDeleted
                                            ? null
                                            : onAuthorTap,
                                        child: Text(
                                          item.isDeleted
                                              ? 'Người dùng'
                                              : item.userName,
                                          key: Key(
                                            'review_author_name_${item.id}',
                                          ),
                                          style: TextStyle(
                                            fontSize: depth == 0 ? 13 : 12.5,
                                            height: 1.25,
                                            fontWeight: FontWeight.w700,
                                            color: item.isDeleted
                                                ? colors.onSurfaceVariant
                                                : colors.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isSpotAuthor && !item.isDeleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'Tác giả',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: colors.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      if (!item.isReply &&
                                          !item.isDeleted &&
                                          item.rating > 0)
                                        Container(
                                          key: Key(
                                            'review_rating_badge_${item.id}',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star_rounded,
                                                size: 11.5,
                                                color: Colors.amber.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${item.rating}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isOwnComment && !item.isDeleted)
                                  PopupMenuButton<String>(
                                    key: Key('review_menu_${item.id}'),
                                    tooltip: 'Tùy chọn bình luận',
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        onEditTap();
                                      } else if (value == 'delete') {
                                        onDeleteTap();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Chỉnh sửa',
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
                                              'Xóa bình luận',
                                              style: TextStyle(
                                                color: colors.error,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: SizedBox(
                                      width: 24,
                                      height: 19,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          size: 17,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (item.isDeleted)
                            Text(
                              'Bình luận này đã bị xóa bởi tác giả.',
                              key: Key('review_deleted_placeholder_${item.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          else
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: depth == 0 ? 13.5 : 13,
                                  height: 1.38,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.92),
                                ),
                                children: [
                                  if (item.isReply &&
                                      (item.replyToUserName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                    TextSpan(
                                      text:
                                          '@${item.replyToUserName!.trim()} ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: colors.primary,
                                      ),
                                    ),
                                  TextSpan(text: item.comment),
                                ],
                              ),
                              key: Key('review_comment_text_${item.id}'),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 3),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            SpotReviewLogic.formatRelativeTime(item.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (item.isEdited && !item.isDeleted)
                            Text(
                              'Đã chỉnh sửa',
                              key: Key('review_edited_badge_${item.id}'),
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          if (!item.isDeleted)
                            InkWell(
                              key: Key('review_reply_button_${item.id}'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: onReplyTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                child: Text(
                                  'Trả lời',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThreadToggleRow extends StatelessWidget {
  const _ThreadToggleRow({
    required this.rootId,
    required this.isExpanded,
    required this.hiddenCount,
    required this.connectorColor,
    required this.onToggle,
  });

  final String rootId;
  final bool isExpanded;
  final int hiddenCount;
  final Color connectorColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final indent = _ThreadTreeMetrics.indent(1);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ThreadConnectorPainter(
                depth: 1,
                ancestorSpines: const [],
                hasNextSibling: false,
                hasVisibleChildren: false,
                lineColor: connectorColor,
                customElbowY: 14.0,
                customTargetX: indent - 2.0,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(indent, 2, 0, 4),
          child: InkWell(
            key: Key('review_toggle_replies_$rootId'),
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.subdirectory_arrow_right_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isExpanded
                        ? 'Thu gọn phản hồi'
                        : 'Xem thêm $hiddenCount phản hồi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReviewInputBar extends ConsumerStatefulWidget {
  const ReviewInputBar({
    super.key,
    this.spot,
    this.spotId,
    this.focusNode,
    this.onRequireLogin,
  }) : assert(spot != null || spotId != null);

  final SpotModel? spot;
  final String? spotId;
  final FocusNode? focusNode;
  final VoidCallback? onRequireLogin;

  @override
  ConsumerState<ReviewInputBar> createState() => _ReviewInputBarState();
}

class _ReviewInputBarState extends ConsumerState<ReviewInputBar> {
  final TextEditingController _controller = TextEditingController();
  FocusNode? _internalFocusNode;
  int _selectedRating = 5;

  String get _spotId => (widget.spot?.id ?? widget.spotId ?? '').trim();
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickStarRating() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chọn số sao đánh giá',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        key: Key('review_pick_star_$star'),
                        onPressed: () => Navigator.of(sheetContext).pop(star),
                        iconSize: 34,
                        icon: Icon(
                          star <= _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: star <= _selectedRating
                              ? Colors.amber.shade600
                              : colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() => _selectedRating = chosen);
    }
  }

  Future<void> _submit() async {
    final currentUserId = ref.read(spotReviewCurrentUserIdProvider);
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (widget.onRequireLogin != null) {
        widget.onRequireLogin!();
      } else {
        _showSnackBar('Vui lòng đăng nhập để gửi bình luận.');
      }
      return;
    }

    final result = await ref
        .read(spotReviewControllerProvider.notifier)
        .submitComment(
          spotId: _spotId,
          userId: currentUserId,
          comment: _controller.text,
          rating: _selectedRating,
        );

    if (!mounted || result.ignored) return;
    if (result.success) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    } else if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      spotReviewControllerProvider.select(
        (map) => (map[_spotId] ?? const ReviewComposerState()).focusRequestId,
      ),
      (previous, next) {
        if (previous != null && next > previous) {
          _focusNode.requestFocus();
        }
      },
    );

    final composer = ref.watch(
      spotReviewControllerProvider.select(
        (map) => map[_spotId] ?? const ReviewComposerState(),
      ),
    );
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 0.7,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (composer.isReplying)
              Container(
                key: const Key('review_reply_banner'),
                width: double.infinity,
                color: colors.primaryContainer.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đang trả lời ${composer.replyingTo!.userName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('review_cancel_reply_button'),
                      tooltip: 'Hủy trả lời',
                      onPressed: composer.isSubmitting
                          ? null
                          : () => ref
                              .read(spotReviewControllerProvider.notifier)
                              .cancelReply(_spotId),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 26,
                        height: 26,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                children: [
                  if (!composer.isReplying) ...[
                    Material(
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('review_rating_picker_button'),
                        onTap: composer.isSubmitting ? null : _pickStarRating,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$_selectedRating',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      key: const Key('review_input_field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !composer.isSubmitting,
                      maxLength: SpotReviewLogic.maxCommentLength,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: colors.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        hintText: composer.isReplying
                            ? 'Trả lời ${composer.replyingTo!.userName}...'
                            : 'Viết bình luận...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: const Key('review_send_button'),
                    tooltip:
                        composer.isReplying ? 'Gửi phản hồi' : 'Gửi bình luận',
                    onPressed: composer.isSubmitting ? null : _submit,
                    icon: composer.isSubmitting
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
            ),
          ],
        ),
      ),
    );
  }
}

class EditReviewSheet extends ConsumerStatefulWidget {
  const EditReviewSheet({
    super.key,
    required this.review,
    required this.currentUserId,
    this.onSaved,
  });

  final SpotReviewItem review;
  final String currentUserId;
  final VoidCallback? onSaved;

  @override
  ConsumerState<EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends ConsumerState<EditReviewSheet> {
  late final TextEditingController _controller;
  late int _rating;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.review.comment);
    _rating = widget.review.isReply
        ? 0
        : SpotReviewLogic.clampRating(widget.review.rating);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final trimmed = _controller.text.trim();
    final validationError = SpotReviewLogic.validateComment(trimmed);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    final unchangedText = trimmed == widget.review.comment.trim();
    final unchangedRating =
        widget.review.isReply || _rating == widget.review.rating;
    if (unchangedText && unchangedRating) {
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(false);
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(spotReviewControllerProvider.notifier)
        .editReview(
          target: widget.review,
          currentUserId: widget.currentUserId,
          comment: trimmed,
          rating: widget.review.isReply ? null : _rating,
        );

    if (!mounted) return;
    if (result.success) {
      setState(() => _isSaving = false);
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage =
            result.errorMessage ?? 'Cập nhật bình luận thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 18 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.review.isReply
                    ? 'Chỉnh sửa phản hồi'
                    : 'Chỉnh sửa đánh giá & bình luận',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!widget.review.isReply) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        key: Key('edit_review_star_$star'),
                        onPressed: _isSaving
                            ? null
                            : () => setState(() => _rating = star),
                        iconSize: 30,
                        icon: Icon(
                          star <= _rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: star <= _rating
                              ? Colors.amber.shade600
                              : colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                key: const Key('edit_review_text_field'),
                controller: _controller,
                enabled: !_isSaving,
                maxLines: 4,
                minLines: 2,
                maxLength: SpotReviewLogic.maxCommentLength,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nội dung bình luận',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('edit_review_error_banner'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('edit_review_save_button'),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Lưu thay đổi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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

class DeleteReviewDialog extends StatelessWidget {
  const DeleteReviewDialog({
    super.key,
    required this.isReply,
  });

  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(isReply ? 'Xóa phản hồi' : 'Xóa bình luận'),
      content: Text(
        isReply
            ? 'Bạn có chắc muốn xóa phản hồi này không? Nếu đã có người trả lời bên dưới, nhánh thảo luận vẫn sẽ được giữ lại.'
            : 'Bạn có chắc muốn xóa bình luận này không? Nếu đã có người trả lời, luồng thảo luận bên dưới vẫn sẽ được giữ lại.',
      ),
      actions: [
        TextButton(
          key: const Key('delete_review_cancel_button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('delete_review_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Xóa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}