import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/social/data/spot_review_repository.dart';
import 'package:spotshare/features/social/presentation/spot_review_controller.dart';
import 'package:spotshare/features/social/presentation/widgets/review_section.dart';

class _TestAuthUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'user_teoem';

  void switchTo(String? uid) => state = uid;
}

final _testAuthUidProvider = NotifierProvider<_TestAuthUidNotifier, String?>(
  _TestAuthUidNotifier.new,
);

class FakeSpotReviewGateway implements SpotReviewGateway {
  FakeSpotReviewGateway({
    ReviewItemList initialItems = const [],
    this.errorOnStream,
    this.errorOnMutation,
    this.enforcedAuthUid,
  }) : _items = List<SpotReviewItem>.from(initialItems);

  final StreamController<ReviewItemList> _controller =
      StreamController<ReviewItemList>.broadcast();
  final ReviewItemList _items;
  Object? errorOnStream;
  Object? errorOnMutation;
  String? enforcedAuthUid;
  int _nextId = 100;

  void dispose() {
    _controller.close();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<SpotReviewItem>.from(_items));
    }
  }

  String _nameForUid(String uid) {
    switch (uid) {
      case 'user_teoem':
      case 'user_me':
        return 'Teo Em';
      case 'user_trungnguyen':
        return 'Phan Mai Trung Nguyên';
      case 'user_maianh':
        return 'Tran Nam Anh';
      case 'user_tan':
        return 'Tấn';
      default:
        return 'Thành viên SpotShare';
    }
  }

  @override
  Stream<ReviewItemList> watchReviews(String spotId) {
    if (errorOnStream != null) {
      return Stream<ReviewItemList>.error(errorOnStream!);
    }
    Future<void>.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<void> addReview({
    required String spotId,
    required String userId,
    required String comment,
    required int rating,
    SpotReviewItem? replyTo,
  }) async {
    if (errorOnMutation != null) {
      throw errorOnMutation!;
    }
    if (enforcedAuthUid != null && userId != enforcedAuthUid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
    }
    final isReply = replyTo != null;
    _items.add(
      SpotReviewItem(
        id: 'rev_${_nextId++}',
        spotId: spotId,
        userId: userId,
        userName: _nameForUid(userId),
        userAvatar: '',
        rating: isReply ? 0 : rating,
        comment: comment.trim(),
        parentId: isReply ? replyTo.threadRootId : null,
        replyToReviewId: isReply ? replyTo.id : null,
        replyToUserId: isReply ? replyTo.userId : null,
        replyToUserName: isReply ? replyTo.userName : null,
        createdAt: DateTime.now(),
      ),
    );
    _emit();
  }

  @override
  Future<void> updateReview({
    required SpotReviewItem target,
    required String currentUserId,
    required String comment,
    int? rating,
  }) async {
    if (errorOnMutation != null) {
      throw errorOnMutation!;
    }
    if (currentUserId != target.userId) {
      throw const SpotReviewException(
        'Bạn chỉ có thể chỉnh sửa bình luận của chính mình.',
        code: 'permission-denied',
      );
    }
    final idx = _items.indexWhere((e) => e.id == target.id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(
        comment: comment.trim(),
        rating: target.isReply ? 0 : (rating ?? target.rating),
        isEdited: true,
        updatedAt: DateTime.now(),
      );
      _emit();
    }
  }

  @override
  Future<void> deleteReview({
    required SpotReviewItem target,
    required String currentUserId,
  }) async {
    if (errorOnMutation != null) {
      throw errorOnMutation!;
    }
    if (currentUserId != target.userId) {
      throw const SpotReviewException(
        'Bạn chỉ có thể xóa bình luận của chính mình.',
        code: 'permission-denied',
      );
    }
    final idx = _items.indexWhere((e) => e.id == target.id);
    if (idx == -1) return;

    final threadItems = _items
        .where((e) => e.parentId == target.threadRootId)
        .toList();
    final hasChildren = SpotReviewLogic.hasActiveChildReplies(
      target: target,
      threadItems: threadItems,
    );
    if (hasChildren) {
      _items[idx] = _items[idx].copyWith(
        isDeleted: true,
        comment: '',
        rating: 0,
        updatedAt: DateTime.now(),
      );
    } else {
      _items.removeAt(idx);
    }
    _emit();
  }
}

void main() {
  group('SpotReviewLogic tree unit tests', () {
    test('validates comment length and rejects blank content', () {
      expect(SpotReviewLogic.validateComment(''), isNotNull);
      expect(SpotReviewLogic.validateComment('    '), isNotNull);
      expect(
        SpotReviewLogic.validateComment('a' * 501),
        contains('tối đa 500'),
      );
      expect(SpotReviewLogic.validateComment('Cảnh đẹp xuất sắc!'), isNull);
    });

    test(
        'builds 3-tier Facebook-style tree (depth 0 -> 1 -> 2), caps deeper replies at depth 2, and supports legacy fallback',
        () {
      final t0 = DateTime(2026, 11, 22, 4, 0);
      final rootTeo = SpotReviewItem(
        id: 'root_teo',
        spotId: 'spot_1',
        userId: 'user_teoem',
        userName: 'Teo Em',
        userAvatar: '',
        rating: 3,
        comment: 'Wyz',
        createdAt: t0,
      );
      final repTrung = SpotReviewItem(
        id: 'rep_trung',
        spotId: 'spot_1',
        userId: 'user_trungnguyen',
        userName: 'Phan Mai Trung Nguyên',
        userAvatar: '',
        rating: 0,
        comment: 'bro?',
        parentId: 'root_teo',
        replyToUserId: 'user_teoem',
        replyToUserName: 'Teo Em',
        createdAt: t0.add(const Duration(minutes: 1)),
      );
      final repAnhToTeo = SpotReviewItem(
        id: 'rep_anh_teo',
        spotId: 'spot_1',
        userId: 'user_maianh',
        userName: 'Tran Nam Anh',
        userAvatar: '',
        rating: 0,
        comment: 'mean?',
        parentId: 'root_teo',
        replyToUserId: 'user_teoem',
        replyToUserName: 'Teo Em',
        createdAt: t0.add(const Duration(minutes: 2)),
      );
      final repAnhToTrungLegacy = SpotReviewItem(
        id: 'rep_anh_trung',
        spotId: 'spot_1',
        userId: 'user_maianh',
        userName: 'Tran Nam Anh',
        userAvatar: '',
        rating: 0,
        comment: '?',
        parentId: 'root_teo',
        replyToUserId: 'user_trungnguyen',
        replyToUserName: 'Phan Mai Trung Nguyên',
        createdAt: t0.add(const Duration(minutes: 3)),
      );
      final repTrungBackToAnh = SpotReviewItem(
        id: 'rep_trung_back',
        spotId: 'spot_1',
        userId: 'user_trungnguyen',
        userName: 'Phan Mai Trung Nguyên',
        userAvatar: '',
        rating: 0,
        comment: 'ok nha',
        parentId: 'root_teo',
        replyToReviewId: 'rep_anh_trung',
        replyToUserId: 'user_maianh',
        replyToUserName: 'Tran Nam Anh',
        createdAt: t0.add(const Duration(minutes: 4)),
      );

      final trees = SpotReviewLogic.buildTreeNodes([
        rootTeo,
        repTrungBackToAnh,
        repAnhToTrungLegacy,
        repAnhToTeo,
        repTrung,
      ]);

      expect(trees.length, 1);
      final root = trees.first;
      expect(root.depth, 0);
      expect(root.children.map((n) => n.item.id).toList(), [
        'rep_trung',
        'rep_anh_teo',
      ]);
      expect(root.children[0].depth, 1);
      expect(root.children[1].depth, 1);
      expect(
        root.children[0].children.map((n) => n.item.id).toList(),
        ['rep_anh_trung', 'rep_trung_back'],
      );
      expect(root.children[0].children[0].depth, 2);
      expect(root.children[0].children[1].depth, 2);

      final collapsed = SpotReviewLogic.buildThreadView(
        rootNode: root,
        isExpanded: false,
        collapsedReplyRowLimit: 3,
      );
      expect(collapsed.hiddenReplyCount, 1);
      expect(collapsed.visibleRows.length, 4);

      final expanded = SpotReviewLogic.buildThreadView(
        rootNode: root,
        isExpanded: true,
        collapsedReplyRowLimit: 3,
      );
      expect(expanded.hiddenReplyCount, 0);
      expect(expanded.visibleRows.map((r) => r.item.id).toList(), [
        'root_teo',
        'rep_trung',
        'rep_anh_trung',
        'rep_trung_back',
        'rep_anh_teo',
      ]);
      expect(expanded.visibleRows[1].hasNextSibling, isTrue);
      expect(expanded.visibleRows[2].ancestorSpines, [true]);
      expect(expanded.visibleRows[2].hasNextSibling, isTrue);
      expect(expanded.visibleRows[3].ancestorSpines, [true]);
      expect(expanded.visibleRows[3].hasNextSibling, isFalse);
      expect(expanded.visibleRows[4].hasNextSibling, isTrue);
    });

    test(
        'prunes empty soft-deleted roots/depth1 nodes and excludes replies from star average',
        () {
      final now = DateTime(2026, 11, 22, 4, 30);
      final items = [
        SpotReviewItem(
          id: 'r1',
          spotId: 'spot_1',
          userId: 'u1',
          userName: 'Tấn',
          userAvatar: '',
          rating: 5,
          comment: 'Rất đẹp!',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        SpotReviewItem(
          id: 'r1_deleted_branch',
          spotId: 'spot_1',
          userId: 'u2',
          userName: 'Teo Em',
          userAvatar: '',
          rating: 0,
          comment: '',
          parentId: 'r1',
          isDeleted: true,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        SpotReviewItem(
          id: 'r1_depth2_child',
          spotId: 'spot_1',
          userId: 'u3',
          userName: 'Tran Nam Anh',
          userAvatar: '',
          rating: 0,
          comment: 'Vẫn giữ nhánh con',
          parentId: 'r1',
          replyToReviewId: 'r1_deleted_branch',
          replyToUserId: 'u2',
          replyToUserName: 'Teo Em',
          createdAt: now.subtract(const Duration(minutes: 30)),
        ),
        SpotReviewItem(
          id: 'r3_deleted_empty',
          spotId: 'spot_1',
          userId: 'u3',
          userName: 'Khách',
          userAvatar: '',
          rating: 0,
          comment: '',
          isDeleted: true,
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
        SpotReviewItem(
          id: 'r4',
          spotId: 'spot_1',
          userId: 'u4',
          userName: 'Vũ',
          userAvatar: '',
          rating: 4,
          comment: 'Đường hơi dốc nhưng đáng đi',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      final trees = SpotReviewLogic.buildTreeNodes(items);
      expect(trees.map((t) => t.item.id).toList(), ['r4', 'r1']);
      expect(trees[1].children.length, 1);
      expect(trees[1].children.first.item.isDeleted, isTrue);
      expect(
        trees[1].children.first.children.map((c) => c.item.id).toList(),
        ['r1_depth2_child'],
      );
      expect(SpotReviewLogic.countActiveComments(trees), 3);

      final summary = SpotReviewLogic.calculateRatingSummary(items);
      expect(summary.ratingCount, 2);
      expect(summary.ratingAvg, 4.5);

      expect(
        SpotReviewLogic.computeRuleSafeRatingCount(
          currentSpotRatingCount: 0,
          delta: -1,
        ),
        0,
      );
      expect(
        SpotReviewLogic.computeRuleSafeRatingCount(
          currentSpotRatingCount: 2,
          delta: 1,
        ),
        3,
      );
    });

    test('maps permission-denied cleanly without exposing raw Firebase codes',
        () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final msg = SpotReviewErrorMapper.map(err);
      expect(msg, contains('không có quyền'));
      expect(msg, isNot(contains('cloud_firestore')));
    });
  });

  group('ReviewSection & ReviewInputBar widget tests', () {
    testWidgets(
        'visually indents depth 0 < depth 1 < depth 2 like Facebook tree and aligns siblings identically regardless of menu button',
        (tester) async {
      final t0 = DateTime.now().subtract(const Duration(hours: 2));
      final gateway = FakeSpotReviewGateway(
        enforcedAuthUid: 'user_maianh',
        initialItems: [
          SpotReviewItem(
            id: 'root_teo',
            spotId: 'spot_tan',
            userId: 'user_teoem',
            userName: 'Teo Em',
            userAvatar: '',
            rating: 3,
            comment: 'Wyz',
            createdAt: t0,
          ),
          SpotReviewItem(
            id: 'rep_trung',
            spotId: 'spot_tan',
            userId: 'user_trungnguyen',
            userName: 'Phan Mai Trung Nguyên',
            userAvatar: '',
            rating: 0,
            comment: 'bro?',
            parentId: 'root_teo',
            replyToReviewId: 'root_teo',
            replyToUserId: 'user_teoem',
            replyToUserName: 'Teo Em',
            createdAt: t0.add(const Duration(minutes: 1)),
          ),
          SpotReviewItem(
            id: 'rep_anh_teo',
            spotId: 'spot_tan',
            userId: 'user_maianh',
            userName: 'Tran Nam Anh',
            userAvatar: '',
            rating: 0,
            comment: 'mean?',
            parentId: 'root_teo',
            replyToReviewId: 'root_teo',
            replyToUserId: 'user_teoem',
            replyToUserName: 'Teo Em',
            createdAt: t0.add(const Duration(minutes: 2)),
          ),
          SpotReviewItem(
            id: 'rep_anh_trung',
            spotId: 'spot_tan',
            userId: 'user_maianh',
            userName: 'Tran Nam Anh',
            userAvatar: '',
            rating: 0,
            comment: '?',
            parentId: 'root_teo',
            replyToReviewId: 'rep_trung',
            replyToUserId: 'user_trungnguyen',
            replyToUserName: 'Phan Mai Trung Nguyên',
            createdAt: t0.add(const Duration(minutes: 3)),
          ),
        ],
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(gateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_maianh'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ReviewSection(
                  spotId: 'spot_tan',
                  spotAuthorId: 'user_tan',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final rootTopLeft =
          tester.getTopLeft(find.byKey(const Key('review_tile_root_teo')));
      final depth1TrungTopLeft =
          tester.getTopLeft(find.byKey(const Key('review_tile_rep_trung')));
      final depth2AnhTopLeft =
          tester.getTopLeft(find.byKey(const Key('review_tile_rep_anh_trung')));
      final depth1AnhTopLeft =
          tester.getTopLeft(find.byKey(const Key('review_tile_rep_anh_teo')));

      expect(depth1TrungTopLeft.dx, greaterThan(rootTopLeft.dx));
      expect(depth1AnhTopLeft.dx, equals(depth1TrungTopLeft.dx));
      expect(depth2AnhTopLeft.dx, greaterThan(depth1TrungTopLeft.dx));

      expect(depth2AnhTopLeft.dy, greaterThan(depth1TrungTopLeft.dy));
      expect(depth1AnhTopLeft.dy, greaterThan(depth2AnhTopLeft.dy));

      final trungNameRect =
          tester.getRect(find.byKey(const Key('review_author_name_rep_trung')));
      final trungCommentRect = tester
          .getRect(find.byKey(const Key('review_comment_text_rep_trung')));
      final anhNameRect = tester
          .getRect(find.byKey(const Key('review_author_name_rep_anh_teo')));
      final anhCommentRect = tester
          .getRect(find.byKey(const Key('review_comment_text_rep_anh_teo')));

      final trungGap = trungCommentRect.top - trungNameRect.bottom;
      final anhGap = anhCommentRect.top - anhNameRect.bottom;
      expect((trungGap - anhGap).abs(), lessThanOrEqualTo(1.0));
    });

    testWidgets(
        'collapses threads with more than 3 replies and expands cleanly on tap',
        (tester) async {
      final t0 = DateTime.now().subtract(const Duration(hours: 1));
      final gateway = FakeSpotReviewGateway(
        enforcedAuthUid: 'user_maianh',
        initialItems: [
          SpotReviewItem(
            id: 'root_1',
            spotId: 'spot_1',
            userId: 'user_tan',
            userName: 'Tấn',
            userAvatar: '',
            rating: 5,
            comment: 'Bài gốc',
            createdAt: t0,
          ),
          for (var i = 1; i <= 4; i++)
            SpotReviewItem(
              id: 'rep_$i',
              spotId: 'spot_1',
              userId: 'user_maianh',
              userName: 'Tran Nam Anh',
              userAvatar: '',
              rating: 0,
              comment: 'Phản hồi thứ $i',
              parentId: 'root_1',
              replyToReviewId: 'root_1',
              replyToUserId: 'user_tan',
              replyToUserName: 'Tấn',
              createdAt: t0.add(Duration(minutes: i)),
            ),
        ],
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(gateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_maianh'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ReviewSection(
                  spotId: 'spot_1',
                  spotAuthorId: 'user_tan',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Xem thêm 1 phản hồi'), findsOneWidget);
      expect(find.byKey(const Key('review_tile_rep_4')), findsNothing);

      final toggle = find.byKey(const Key('review_toggle_replies_root_1'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_tile_rep_4')), findsOneWidget);
      expect(find.text('Thu gọn phản hồi'), findsOneWidget);
    });

    testWidgets(
        'replies to another user comment, edits own comment with star change, and deletes cleanly',
        (tester) async {
      final now = DateTime.now();
      final gateway = FakeSpotReviewGateway(
        enforcedAuthUid: 'user_me',
        initialItems: [
          SpotReviewItem(
            id: 'root_other',
            spotId: 'spot_1',
            userId: 'user_tan',
            userName: 'Tấn',
            userAvatar: '',
            rating: 5,
            comment: 'Hoàng hôn ở đây cực kỳ đẹp!',
            createdAt: now.subtract(const Duration(minutes: 20)),
          ),
          SpotReviewItem(
            id: 'root_mine',
            spotId: 'spot_1',
            userId: 'user_me',
            userName: 'Teo Em',
            userAvatar: '',
            rating: 4,
            comment: 'Đường đi dễ chạy xe máy.',
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        ],
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(gateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_me'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: ReviewSection(
                        spotId: 'spot_1',
                        spotAuthorId: 'user_tan',
                      ),
                    ),
                  ),
                  ReviewInputBar(spotId: 'spot_1'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tác giả'), findsOneWidget);
      expect(find.byKey(const Key('review_menu_root_other')), findsNothing);
      expect(find.byKey(const Key('review_menu_root_mine')), findsOneWidget);

      final replyButton =
          find.byKey(const Key('review_reply_button_root_other'));
      await tester.ensureVisible(replyButton);
      await tester.pumpAndSettle();
      await tester.tap(replyButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_reply_banner')), findsOneWidget);
      expect(find.text('Đang trả lời Tấn'), findsOneWidget);
      expect(
        find.byKey(const Key('review_rating_picker_button')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('review_input_field')),
        'Mấy giờ ra chụp là đẹp nhất bạn?',
      );
      await tester.tap(find.byKey(const Key('review_send_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_reply_banner')), findsNothing);
      expect(
        find.textContaining('Mấy giờ ra chụp là đẹp nhất bạn?'),
        findsOneWidget,
      );

      final myMenu = find.byKey(const Key('review_menu_root_mine'));
      await tester.ensureVisible(myMenu);
      await tester.pumpAndSettle();
      await tester.tap(myMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉnh sửa'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_review_star_5')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('edit_review_text_field')),
        'Đường đi siêu đẹp, vừa nâng lên 5 sao!',
      );
      final saveButton = find.byKey(const Key('edit_review_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đường đi siêu đẹp, vừa nâng lên 5 sao!'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('review_edited_badge_root_mine')),
        findsOneWidget,
      );

      await tester.ensureVisible(myMenu);
      await tester.pumpAndSettle();
      await tester.tap(myMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa bình luận'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_review_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_tile_root_mine')), findsNothing);
    });

    testWidgets(
        'soft-deletes depth-1 reply when it has depth-2 child so child branch remains intact',
        (tester) async {
      final t0 = DateTime.now().subtract(const Duration(minutes: 20));
      final gateway = FakeSpotReviewGateway(
        enforcedAuthUid: 'user_trungnguyen',
        initialItems: [
          SpotReviewItem(
            id: 'root_teo',
            spotId: 'spot_1',
            userId: 'user_teoem',
            userName: 'Teo Em',
            userAvatar: '',
            rating: 4,
            comment: 'Bình luận gốc',
            createdAt: t0,
          ),
          SpotReviewItem(
            id: 'depth1_trung',
            spotId: 'spot_1',
            userId: 'user_trungnguyen',
            userName: 'Phan Mai Trung Nguyên',
            userAvatar: '',
            rating: 0,
            comment: 'Hỏi thêm chút',
            parentId: 'root_teo',
            replyToReviewId: 'root_teo',
            replyToUserId: 'user_teoem',
            replyToUserName: 'Teo Em',
            createdAt: t0.add(const Duration(minutes: 2)),
          ),
          SpotReviewItem(
            id: 'depth2_anh',
            spotId: 'spot_1',
            userId: 'user_maianh',
            userName: 'Tran Nam Anh',
            userAvatar: '',
            rating: 0,
            comment: 'Mình trả lời giúp bạn nè',
            parentId: 'root_teo',
            replyToReviewId: 'depth1_trung',
            replyToUserId: 'user_trungnguyen',
            replyToUserName: 'Phan Mai Trung Nguyên',
            createdAt: t0.add(const Duration(minutes: 4)),
          ),
        ],
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(gateway),
            spotReviewCurrentUserIdProvider.overrideWithValue('user_trungnguyen'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ReviewSection(
                  spotId: 'spot_1',
                  spotAuthorId: 'user_tan',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('review_menu_depth1_trung')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa bình luận'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_review_confirm_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('review_deleted_placeholder_depth1_trung')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review_tile_depth2_anh')), findsOneWidget);
    });

    testWidgets(
        'switches active UID cleanly and avoids overflow at depth 2 in Dark Mode on 5.5 inch 1.3x viewport',
        (tester) async {
      final t0 = DateTime.now().subtract(const Duration(minutes: 30));
      final gateway = FakeSpotReviewGateway(
        enforcedAuthUid: 'user_teoem',
        initialItems: [
          SpotReviewItem(
            id: 'rev_teoem',
            spotId: 'spot_tan',
            userId: 'user_teoem',
            userName: 'Teo Em',
            userAvatar: '',
            rating: 3,
            comment: 'Wyz',
            createdAt: t0,
          ),
          SpotReviewItem(
            id: 'rev_trung',
            spotId: 'spot_tan',
            userId: 'user_trungnguyen',
            userName: 'Phan Mai Trung Nguyên',
            userAvatar: '',
            rating: 0,
            comment: 'Chỗ này có gửi xe miễn phí không bạn ơi?',
            parentId: 'rev_teoem',
            replyToReviewId: 'rev_teoem',
            replyToUserId: 'user_teoem',
            replyToUserName: 'Teo Em',
            createdAt: t0.add(const Duration(minutes: 3)),
          ),
          SpotReviewItem(
            id: 'rev_anh',
            spotId: 'spot_tan',
            userId: 'user_maianh',
            userName: 'Tran Nam Anh',
            userAvatar: '',
            rating: 0,
            comment: 'Có bãi gửi xe ngay cổng luôn, 5k một chiếc xe máy nhé!',
            parentId: 'rev_teoem',
            replyToReviewId: 'rev_trung',
            replyToUserId: 'user_trungnguyen',
            replyToUserName: 'Phan Mai Trung Nguyên',
            createdAt: t0.add(const Duration(minutes: 5)),
          ),
        ],
      );
      addTearDown(gateway.dispose);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReviewGatewayProvider.overrideWithValue(gateway),
            spotReviewCurrentUserIdProvider.overrideWith(
              (ref) => ref.watch(_testAuthUidProvider),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context, listen: false);
              return MaterialApp(
                themeMode: ThemeMode.dark,
                darkTheme: CompactUiTheme.dark(),
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                  child: const Scaffold(
                    body: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: ReviewSection(
                              spotId: 'spot_tan',
                              spotAuthorId: 'user_tan',
                            ),
                          ),
                        ),
                        ReviewInputBar(spotId: 'spot_tan'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('review_menu_rev_teoem')), findsOneWidget);

      gateway.enforcedAuthUid = 'user_maianh';
      container.read(_testAuthUidProvider.notifier).switchTo('user_maianh');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_menu_rev_teoem')), findsNothing);
      expect(find.byKey(const Key('review_menu_rev_anh')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}