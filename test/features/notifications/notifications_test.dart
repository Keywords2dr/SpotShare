import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/notifications/data/notifications_repository.dart';
import 'package:spotshare/features/notifications/presentation/notifications_controller.dart';
import 'package:spotshare/features/notifications/presentation/notifications_screen.dart';
import 'package:spotshare/features/social/data/spot_review_repository.dart';
import 'package:spotshare/features/social/presentation/spot_review_controller.dart';
import 'package:spotshare/features/social/presentation/widgets/review_section.dart';

class _TestNotifUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'user_vu';

  void setUid(String? uid) => state = uid;
}

final _testNotifUidProvider = NotifierProvider<_TestNotifUidNotifier, String?>(
  _TestNotifUidNotifier.new,
);

class _FakeSpotReviewGateway implements SpotReviewGateway {
  _FakeSpotReviewGateway(this.items);

  final ReviewItemList items;

  @override
  Stream<ReviewItemList> watchReviews(String spotId) => Stream.value(items);

  @override
  Future<void> addReview({
    required String spotId,
    required String userId,
    required String comment,
    required int rating,
    SpotReviewItem? replyTo,
  }) async {}

  @override
  Future<void> updateReview({
    required SpotReviewItem target,
    required String currentUserId,
    required String comment,
    int? rating,
  }) async {}

  @override
  Future<void> deleteReview({
    required SpotReviewItem target,
    required String currentUserId,
  }) async {}
}

class FakeNotificationsGateway implements NotificationsGateway {
  FakeNotificationsGateway({
    NotificationList initialItems = const [],
    this.errorOnStream,
    this.errorOnMutation,
  }) : _items = List<NotificationItem>.from(initialItems);

  final StreamController<NotificationList> _controller =
      StreamController<NotificationList>.broadcast();
  final NotificationList _items;
  Object? errorOnStream;
  Object? errorOnMutation;
  int markAsReadCalls = 0;
  int markAllAsReadCalls = 0;
  int deleteCalls = 0;

  bool get hasListeners => _controller.hasListener;

  void emitCurrent() {
    if (!_controller.isClosed) {
      _controller.add(NotificationsLogic.sortByNewest(_items));
    }
  }

  void dispose() {
    _controller.close();
  }

  @override
  Stream<NotificationList> watchNotifications({
    required String userId,
    int limit = 60,
  }) {
    if (errorOnStream != null) {
      return Stream<NotificationList>.error(errorOnStream!);
    }
    Future<void>.microtask(emitCurrent);
    return _controller.stream;
  }

  @override
  Future<void> sendNotification({
    required String recipientId,
    required String actorId,
    String actorName = '',
    String actorAvatar = '',
    required NotificationType type,
    String spotId = '',
    String spotTitle = '',
    String spotThumbnail = '',
    String reviewId = '',
    String commentPreview = '',
  }) async {
    if (!NotificationsLogic.shouldNotify(
      recipientId: recipientId,
      actorId: actorId,
    )) {
      return;
    }
    final id = NotificationsLogic.deterministicId(
          type: type,
          actorId: actorId,
          spotId: spotId,
        ) ??
        'notif_${_items.length + 1}';
    _items.removeWhere((item) => item.id == id);
    _items.insert(
      0,
      NotificationItem(
        id: id,
        recipientId: recipientId,
        actorId: actorId,
        actorName: actorName.isNotEmpty ? actorName : 'Thành viên',
        actorAvatar: actorAvatar,
        type: type,
        spotId: spotId,
        spotTitle: spotTitle,
        spotThumbnail: spotThumbnail,
        reviewId: reviewId,
        commentPreview: NotificationsLogic.truncatePreview(commentPreview),
        isRead: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    emitCurrent();
  }

  @override
  Future<void> removeInteractionNotification({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    String spotId = '',
  }) async {
    final id = NotificationsLogic.deterministicId(
      type: type,
      actorId: actorId,
      spotId: spotId,
    );
    if (id == null) return;
    _items.removeWhere((item) => item.id == id);
    emitCurrent();
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    markAsReadCalls++;
    if (errorOnMutation != null) throw errorOnMutation!;
    final idx = _items.indexWhere((e) => e.id == notificationId);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(isRead: true);
      emitCurrent();
    }
  }

  @override
  Future<void> markAllAsRead({
    required String userId,
    required List<String> unreadNotificationIds,
  }) async {
    markAllAsReadCalls++;
    if (errorOnMutation != null) throw errorOnMutation!;
    for (var i = 0; i < _items.length; i++) {
      if (unreadNotificationIds.contains(_items[i].id)) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
    emitCurrent();
  }

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    deleteCalls++;
    if (errorOnMutation != null) throw errorOnMutation!;
    _items.removeWhere((e) => e.id == notificationId);
    emitCurrent();
  }
}

NotificationList _sampleNotifications() {
  final now = DateTime.now();
  return [
    NotificationItem(
      id: 'like_spot_ky_co_u_tan',
      recipientId: 'user_vu',
      actorId: 'u_tan',
      actorName: 'Tấn',
      type: NotificationType.like,
      spotId: 'spot_ky_co',
      spotTitle: 'Bãi biển Kỳ Co',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 5)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      id: 'follow_u_anh',
      recipientId: 'user_vu',
      actorId: 'u_anh',
      actorName: 'Trần Nam Anh',
      type: NotificationType.follow,
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    NotificationItem(
      id: 'comment_1',
      recipientId: 'user_vu',
      actorId: 'u_teo',
      actorName: 'Teo Em',
      type: NotificationType.comment,
      spotId: 'spot_chua',
      spotTitle: 'Chùa Ông Núi',
      reviewId: 'rev_chua_1',
      commentPreview: 'Sáng sớm leo lên đây mát rượi luôn bạn ơi!',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

ReviewItemList _sampleDeepThreadReviews() {
  final base = DateTime(2026, 11, 27, 8, 0);
  return [
    SpotReviewItem(
      id: 'root_1',
      spotId: 'spot_ky_co',
      userId: 'u_tan',
      userName: 'Tấn',
      userAvatar: '',
      rating: 5,
      comment: 'Bãi biển cực đẹp, nước trong xanh!',
      createdAt: base,
    ),
    for (var i = 1; i <= 4; i++)
      SpotReviewItem(
        id: 'reply_$i',
        spotId: 'spot_ky_co',
        userId: 'u_$i',
        userName: 'Bạn $i',
        userAvatar: '',
        rating: 0,
        comment: 'Phản hồi số $i',
        parentId: 'root_1',
        replyToReviewId: 'root_1',
        replyToUserId: 'u_tan',
        replyToUserName: 'Tấn',
        createdAt: base.add(Duration(minutes: i)),
      ),
    SpotReviewItem(
      id: 'reply_5',
      spotId: 'spot_ky_co',
      userId: 'u_5',
      userName: 'Lan',
      userAvatar: '',
      rating: 0,
      comment: 'Đi lúc 6h sáng nắng đẹp lắm luôn!',
      parentId: 'root_1',
      replyToReviewId: 'reply_4',
      replyToUserId: 'u_4',
      replyToUserName: 'Bạn 4',
      createdAt: base.add(const Duration(minutes: 5)),
    ),
  ];
}

void main() {
  group('NotificationsLogic & error mapper unit tests', () {
    test(
        'blocks self notifications and builds deterministic IDs for like/follow only',
        () {
      expect(
        NotificationsLogic.shouldNotify(recipientId: 'u1', actorId: 'u1'),
        isFalse,
      );
      expect(
        NotificationsLogic.shouldNotify(recipientId: 'u1', actorId: 'u2'),
        isTrue,
      );
      expect(
        NotificationsLogic.deterministicId(
          type: NotificationType.like,
          actorId: 'u2',
          spotId: 'spot_1',
        ),
        'like_spot_1_u2',
      );
      expect(
        NotificationsLogic.deterministicId(
          type: NotificationType.follow,
          actorId: 'u2',
        ),
        'follow_u2',
      );
      expect(
        NotificationsLogic.deterministicId(
          type: NotificationType.comment,
          actorId: 'u2',
          spotId: 'spot_1',
        ),
        isNull,
      );
      expect(
        NotificationsLogic.deterministicId(
          type: NotificationType.reply,
          actorId: 'u2',
          spotId: 'spot_1',
        ),
        isNull,
      );
    });

    test(
        'formats relative time, truncates long previews, and maps Firebase errors cleanly',
        () {
      final now = DateTime(2026, 11, 26, 20, 0);
      expect(
        NotificationsLogic.formatRelativeTime(
          now.subtract(const Duration(seconds: 20)),
          now: now,
        ),
        'Vừa xong',
      );
      expect(
        NotificationsLogic.formatRelativeTime(
          now.subtract(const Duration(minutes: 12)),
          now: now,
        ),
        '12 phút trước',
      );
      expect(
        NotificationsLogic.formatRelativeTime(
          now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        '3 giờ trước',
      );
      expect(
        NotificationsLogic.formatRelativeTime(
          now.subtract(const Duration(days: 10)),
          now: now,
        ),
        '16/11/2026',
      );

      final longText = 'A' * 120;
      expect(NotificationsLogic.truncatePreview(longText).length, 90);

      final denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final mapped = NotificationsErrorMapper.map(denied);
      expect(mapped, contains('chưa có quyền'));
      expect(mapped, isNot(contains('cloud_firestore')));
    });

    test('resolves thread root ID for root, depth-1, and depth-2 replies', () {
      final trees = SpotReviewLogic.buildTreeNodes(_sampleDeepThreadReviews());

      expect(
        ReviewDeepLinkLogic.findThreadRootId(trees: trees, reviewId: 'root_1'),
        'root_1',
      );
      expect(
        ReviewDeepLinkLogic.findThreadRootId(trees: trees, reviewId: 'reply_2'),
        'root_1',
      );
      expect(
        ReviewDeepLinkLogic.findThreadRootId(trees: trees, reviewId: 'reply_5'),
        'root_1',
      );
      expect(
        ReviewDeepLinkLogic.findThreadRootId(
          trees: trees,
          reviewId: 'non_existent',
        ),
        isNull,
      );
      expect(ReviewDeepLinkLogic.highlightOpacity(0.2), 1.0);
      expect(ReviewDeepLinkLogic.highlightOpacity(1.0), 0.0);
    });
  });

  group('NotificationsController unit tests', () {
    test(
        'streams notifications, computes unread count, handles optimistic updates/rollback, and cancels on sign-out',
        () async {
      final gateway = FakeNotificationsGateway(
        initialItems: _sampleNotifications(),
      );
      addTearDown(gateway.dispose);

      final container = ProviderContainer(
        overrides: [
          notificationsGatewayProvider.overrideWithValue(gateway),
          notificationsCurrentUserIdProvider.overrideWith(
            (ref) => ref.watch(_testNotifUidProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(notificationsControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(unreadNotificationsCountProvider), 2);
      expect(gateway.hasListeners, isTrue);

      gateway.errorOnMutation = const NotificationsException('Lỗi mạng');
      final failErr = await container
          .read(notificationsControllerProvider.notifier)
          .markAsRead('like_spot_ky_co_u_tan');
      expect(failErr, 'Lỗi mạng');
      expect(container.read(unreadNotificationsCountProvider), 2);

      gateway.errorOnMutation = null;
      final okErr = await container
          .read(notificationsControllerProvider.notifier)
          .markAllAsRead();
      expect(okErr, isNull);
      expect(container.read(unreadNotificationsCountProvider), 0);

      container.read(_testNotifUidProvider.notifier).setUid(null);
      container.read(notificationsControllerProvider);
      expect(gateway.hasListeners, isFalse);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });
  });

  group('NotificationsScreen & Review deep-link widget tests', () {
    testWidgets(
        'filters notifications, routes comments directly with reviewId, marks read on tap, and routes likes/follows',
        (tester) async {
      final gateway = FakeNotificationsGateway(
        initialItems: _sampleNotifications(),
      );
      addTearDown(gateway.dispose);
      String? openedSpotId;
      String? openedReviewSpotId;
      String? openedReviewId;
      String? openedUserId;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsGatewayProvider.overrideWithValue(gateway),
            notificationsCurrentUserIdProvider.overrideWithValue('user_vu'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: NotificationsScreen(
              onSpotTap: (id) => openedSpotId = id,
              onReviewTap: (spotId, reviewId) {
                openedReviewSpotId = spotId;
                openedReviewId = reviewId;
              },
              onUserTap: (uid) => openedUserId = uid,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_unread_pill')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('notification_tile_like_spot_ky_co_u_tan')),
      );
      await tester.pumpAndSettle();

      expect(openedSpotId, 'spot_ky_co');
      expect(gateway.markAsReadCalls, 1);

      await tester.tap(find.byKey(const Key('notification_tile_comment_1')));
      await tester.pumpAndSettle();
      expect(openedReviewSpotId, 'spot_chua');
      expect(openedReviewId, 'rev_chua_1');

      await tester.tap(find.byKey(const Key('notifications_filter_follows')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification_tile_follow_u_anh')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notification_tile_comment_1')), findsNothing);

      await tester.tap(find.byKey(const Key('notification_tile_follow_u_anh')));
      await tester.pumpAndSettle();
      expect(openedUserId, 'u_anh');
    });

    testWidgets(
        'auto-expands hidden reply thread and highlights target comment, then fades out cleanly',
        (tester) async {
      final reviewGateway =
          _FakeSpotReviewGateway(_sampleDeepThreadReviews());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(reviewGateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_vu'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 500),
                    ReviewSection(
                      spotId: 'spot_ky_co',
                      spotAuthorId: 'user_vu',
                      initialReviewId: 'reply_5',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('review_tile_reply_5')), findsOneWidget);
      expect(
        find.byKey(const Key('review_focused_highlight_reply_5')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_tile_reply_5')), findsOneWidget);
      expect(
        find.byKey(const Key('review_focused_highlight_reply_5')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows feedback when linked comment no longer exists',
        (tester) async {
      final reviewGateway =
          _FakeSpotReviewGateway(_sampleDeepThreadReviews());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(reviewGateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_vu'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ReviewSection(
                  spotId: 'spot_ky_co',
                  spotAuthorId: 'user_vu',
                  initialReviewId: 'deleted_review_404',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Bình luận này không còn tồn tại.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'shows error retry state and renders cleanly in Dark Mode 5.5 inch 1.3x viewport without overflow',
        (tester) async {
      final gateway = FakeNotificationsGateway(
        errorOnStream: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      addTearDown(gateway.dispose);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsGatewayProvider.overrideWithValue(gateway),
            notificationsCurrentUserIdProvider.overrideWithValue('user_vu'),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: CompactUiTheme.dark(),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: NotificationsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications_retry_button')), findsOneWidget);

      gateway.errorOnStream = null;
      await gateway.sendNotification(
        recipientId: 'user_vu',
        actorId: 'u_tan',
        actorName: 'Tấn',
        type: NotificationType.comment,
        spotId: 'spot_1',
        spotTitle: 'Cung đường biển Quy Nhơn',
        commentPreview: 'Chỗ này chụp hoàng hôn siêu đỉnh luôn!',
      );

      await tester.tap(find.byKey(const Key('notifications_retry_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('notifications_list')), findsOneWidget);
    });
  });
}