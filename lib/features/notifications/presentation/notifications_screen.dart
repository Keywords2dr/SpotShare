import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/cloudinary_url_helper.dart';
import '../data/notifications_repository.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.onSpotTap,
    this.onReviewTap,
    this.onUserTap,
    this.onExploreTap,
  });

  final void Function(String spotId)? onSpotTap;
  final void Function(String spotId, String reviewId)? onReviewTap;
  final void Function(String userId)? onUserTap;
  final VoidCallback? onExploreTap;

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleTapItem(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
  ) async {
    if (!item.isRead) {
      final err = await ref
          .read(notificationsControllerProvider.notifier)
          .markAsRead(item.id);
      if (err != null && context.mounted) {
        _showSnackBar(context, err);
      }
    }
    if (!context.mounted) return;

    if (item.type == NotificationType.follow || !item.hasSpotTarget) {
      if (item.actorId.isEmpty) return;
      if (onUserTap != null) {
        onUserTap!(item.actorId);
      } else {
        GoRouter.maybeOf(context)?.push('/users/${item.actorId}');
      }
      return;
    }

    final hasReviewTarget = (item.type == NotificationType.comment ||
            item.type == NotificationType.reply) &&
        item.reviewId.isNotEmpty;

    if (hasReviewTarget) {
      if (onReviewTap != null) {
        onReviewTap!(item.spotId, item.reviewId);
        return;
      }
      if (onSpotTap != null) {
        onSpotTap!(item.spotId);
        return;
      }
      final uri = Uri(
        path: '/spots/${item.spotId}',
        queryParameters: {'reviewId': item.reviewId},
      );
      GoRouter.maybeOf(context)?.push(uri.toString());
      return;
    }

    if (onSpotTap != null) {
      onSpotTap!(item.spotId);
    } else {
      GoRouter.maybeOf(context)?.push('/spots/${item.spotId}');
    }
  }

  Future<void> _handleMarkAllRead(BuildContext context, WidgetRef ref) async {
    final err = await ref
        .read(notificationsControllerProvider.notifier)
        .markAllAsRead();
    if (!context.mounted) return;
    if (err != null) {
      _showSnackBar(context, err);
    } else {
      _showSnackBar(context, 'Đã đánh dấu tất cả thông báo là đã đọc.');
    }
  }

  Future<void> _handleDeleteItem(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
  ) async {
    final err = await ref
        .read(notificationsControllerProvider.notifier)
        .deleteNotification(item.id);
    if (err != null && context.mounted) {
      _showSnackBar(context, err);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(notificationsControllerProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Hộp thư',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (viewState.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                key: const Key('notifications_unread_pill'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  viewState.unreadCount > 99
                      ? '99+'
                      : '${viewState.unreadCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (viewState.unreadCount > 0)
            TextButton(
              key: const Key('notifications_mark_all_read_button'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: viewState.isMutating
                  ? null
                  : () => _handleMarkAllRead(context, ref),
              child: const Text(
                'Đọc tất cả',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _NotificationFilterBar(
            activeFilter: viewState.activeFilter,
            unreadCount: viewState.unreadCount,
            onSelect: (filter) => ref
                .read(notificationsControllerProvider.notifier)
                .setFilter(filter),
          ),
          Divider(
            height: 0.6,
            thickness: 0.6,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: _buildBody(context, ref, viewState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsViewState viewState,
  ) {
    if (viewState.isInitialLoading) {
      return const _NotificationsLoadingList();
    }

    if (viewState.errorMessage != null && viewState.items.isEmpty) {
      return _NotificationsMessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Không thể tải thông báo',
        message: viewState.errorMessage!,
        actionLabel: 'Thử lại',
        actionKey: const Key('notifications_retry_button'),
        onAction: () =>
            ref.read(notificationsControllerProvider.notifier).refresh(),
      );
    }

    final filtered = viewState.filteredItems;
    if (filtered.isEmpty) {
      final isFiltering = viewState.activeFilter != NotificationFilter.all;
      return _NotificationsMessageState(
        icon: isFiltering
            ? Icons.filter_list_off_rounded
            : Icons.notifications_none_rounded,
        title: isFiltering
            ? 'Không có thông báo trong mục này'
            : 'Chưa có thông báo nào',
        message: isFiltering
            ? 'Chuyển về mục Tất cả để xem toàn bộ tương tác của bạn.'
            : 'Khi có người thả tim, theo dõi hoặc bình luận vào bài viết của bạn, thông báo sẽ hiện ngay tại đây.',
        actionLabel: isFiltering ? 'Xem tất cả' : 'Khám phá ngay',
        actionKey: Key(
          isFiltering
              ? 'notifications_reset_filter_button'
              : 'notifications_explore_button',
        ),
        onAction: () {
          if (isFiltering) {
            ref
                .read(notificationsControllerProvider.notifier)
                .setFilter(NotificationFilter.all);
          } else if (onExploreTap != null) {
            onExploreTap!();
          } else {
            GoRouter.maybeOf(context)?.go('/explore');
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationsControllerProvider.notifier).refresh(),
      child: ListView.separated(
        key: const Key('notifications_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: filtered.length,
        separatorBuilder: (context, _) => Divider(
          height: 0.6,
          indent: 72,
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.35),
        ),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _NotificationTile(
            item: item,
            onTap: () => _handleTapItem(context, ref, item),
            onDismissed: () => _handleDeleteItem(context, ref, item),
          );
        },
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.activeFilter,
    required this.unreadCount,
    required this.onSelect,
  });

  final NotificationFilter activeFilter;
  final int unreadCount;
  final ValueChanged<NotificationFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final barHeight = 46.0 + ((textScale - 1.0) * 18.0);

    final options = [
      (NotificationFilter.all, 'Tất cả'),
      (
        NotificationFilter.unread,
        unreadCount > 0 ? 'Chưa đọc ($unreadCount)' : 'Chưa đọc',
      ),
      (NotificationFilter.likes, 'Thích'),
      (NotificationFilter.comments, 'Bình luận'),
      (NotificationFilter.follows, 'Theo dõi'),
    ];

    return SizedBox(
      height: barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = options[index];
          final selected = activeFilter == filter;
          return ChoiceChip(
            key: Key('notifications_filter_${filter.name}'),
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: selected,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  (IconData, Color) _badgeMeta(ColorScheme colors) {
    switch (item.type) {
      case NotificationType.like:
        return (Icons.favorite_rounded, colors.error);
      case NotificationType.follow:
        return (Icons.person_add_alt_1_rounded, colors.primary);
      case NotificationType.comment:
        return (Icons.chat_bubble_rounded, Colors.teal.shade600);
      case NotificationType.reply:
        return (Icons.reply_rounded, colors.secondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (badgeIcon, badgeColor) = _badgeMeta(colors);

    final avatarUrl = item.actorAvatar.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(item.actorAvatar)
        : '';
    final thumbUrl = item.spotThumbnail.isNotEmpty
        ? CloudinaryUrlHelper.feedThumbnail(item.spotThumbnail)
        : '';
    final initial = item.actorName.isNotEmpty
        ? item.actorName.substring(0, 1).toUpperCase()
        : 'S';

    return Dismissible(
      key: ValueKey<String>('notification_dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.onError,
        ),
      ),
      child: Material(
        color: item.isRead
            ? colors.surface
            : colors.primaryContainer.withValues(alpha: 0.22),
        child: InkWell(
          key: Key('notification_tile_${item.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.surfaceContainerHighest,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        onBackgroundImageError:
                            avatarUrl.isNotEmpty ? (_, _) {} : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurfaceVariant,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            badgeIcon,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: item.actorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: ' ${item.actionDescription}',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.32,
                        ),
                      ),
                      if (item.commentPreview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${item.commentPreview}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              NotificationsLogic.formatRelativeTime(
                                item.effectiveTime,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: item.isRead
                                    ? colors.onSurfaceVariant
                                    : colors.primary,
                                fontWeight: item.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              key: Key('notification_unread_dot_${item.id}'),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (thumbUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: colors.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.landscape_outlined,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsLoadingList extends StatelessWidget {
  const _NotificationsLoadingList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      key: const Key('notifications_loading_list'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsMessageState extends StatelessWidget {
  const _NotificationsMessageState({
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