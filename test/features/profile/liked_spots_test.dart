import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/profile/data/liked_spots_repository.dart';
import 'package:spotshare/features/profile/presentation/liked_spots_controller.dart';
import 'package:spotshare/features/profile/presentation/widgets/liked_spots_tab.dart';
import 'package:spotshare/features/spots/data/spot_like_repository.dart';
import 'package:spotshare/features/spots/presentation/like/spot_like_controller.dart';

class FakeLikedSpotsGateway implements LikedSpotsGateway {
  FakeLikedSpotsGateway({
    this.items = const [],
    this.errorToThrow,
    this.completer,
  });

  List<LikedSpotItem> items;
  Object? errorToThrow;
  Completer<void>? completer;
  int fetchCalls = 0;

  @override
  Future<List<LikedSpotItem>> fetchLikedSpots({
    required String userId,
    bool cleanupOrphans = false,
  }) async {
    fetchCalls++;
    if (completer != null) {
      await completer!.future;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return List<LikedSpotItem>.from(items);
  }
}

class FakeProfileSpotLikeGateway implements SpotLikeGateway {
  FakeProfileSpotLikeGateway({this.errorToThrow});

  Object? errorToThrow;
  final List<String> toggledSpotIds = [];

  @override
  Stream<bool> watchIsLiked({
    required String spotId,
    required String userId,
  }) {
    return Stream<bool>.value(true);
  }

  @override
  Future<SpotLikeResult> toggleLike({
    required String spotId,
    required String userId,
    String? authorId,
  }) async {
    toggledSpotIds.add(spotId);
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return const SpotLikeResult(isLiked: false, likesCount: 0);
  }
}

void main() {
  group('LikedSpotsLogic & error mapper', () {
    test('chunks unique spot IDs safely for Firestore whereIn limit', () {
      final ids = [
        for (var i = 1; i <= 23; i++) 'spot_$i',
        'spot_1',
        '   ',
        '',
      ];
      final chunks = LikedSpotsLogic.chunkSpotIds(ids);

      expect(chunks.length, 3);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 10);
      expect(chunks[2].length, 3);
    });

    test('merges duplicate records keeping newest likedAt and sorts descending',
        () {
      final t1 = DateTime(2026, 11, 20, 10, 0);
      final t2 = DateTime(2026, 11, 21, 12, 0);
      final t3 = DateTime(2026, 11, 21, 15, 30);

      final merged = LikedSpotsLogic.mergeAndSortRecords([
        LikedSpotRefRecord(spotId: 'spot_a', likedAt: t1),
        LikedSpotRefRecord(spotId: 'spot_b', likedAt: t2),
        LikedSpotRefRecord(spotId: 'spot_a', likedAt: t3),
        const LikedSpotRefRecord(spotId: 'spot_c'),
      ]);

      expect(merged.map((e) => e.spotId).toList(), [
        'spot_a',
        'spot_b',
        'spot_c',
      ]);
      expect(merged.first.likedAt, t3);
    });

    test('detects orphaned records for deleted spots', () {
      const records = [
        LikedSpotRefRecord(spotId: 'spot_1'),
        LikedSpotRefRecord(spotId: 'spot_deleted'),
      ];
      final orphans = LikedSpotsLogic.detectOrphanRecords(
        requestedRecords: records,
        existingSpotIds: {'spot_1'},
      );
      expect(orphans.map((e) => e.spotId).toList(), ['spot_deleted']);
    });

    test('maps permission-denied to friendly Vietnamese without raw codes', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      final msg = LikedSpotsErrorMapper.map(err);
      expect(msg, contains('chưa có quyền'));
      expect(msg, isNot(contains('cloud_firestore/')));
    });
  });

  group('LikedSpotsController unit tests', () {
    test('loads liked spots, removes optimistically on unlike, and rolls back on failure',
        () async {
      const sampleItem = LikedSpotItem(
        id: 'spot_kyaru',
        title: 'Lâu đài Kyaru',
        category: 'Di tích / Văn hóa',
        thumbnailUrl: '',
        authorId: 'author_tan',
        authorName: 'Tấn',
        likesCount: 4,
        ratingAvg: 4.5,
        ratingCount: 2,
      );

      final fakeLikedGateway = FakeLikedSpotsGateway(items: [sampleItem]);
      final fakeLikeGateway = FakeProfileSpotLikeGateway();

      final container = ProviderContainer(
        overrides: [
          likedSpotsGatewayProvider.overrideWithValue(fakeLikedGateway),
          spotLikeGatewayProvider.overrideWithValue(fakeLikeGateway),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(likedSpotsControllerProvider.notifier);
      await controller.load(userId: 'user_teo');

      var view = controller.stateFor('user_teo');
      expect(view.items.length, 1);
      expect(view.errorMessage, isNull);

      fakeLikeGateway.errorToThrow = const SpotLikeException(
        'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.',
        code: 'unavailable',
      );
      final rollbackErr = await controller.unlikeSpot(
        userId: 'user_teo',
        item: sampleItem,
      );
      expect(rollbackErr, contains('Mất kết nối mạng'));
      expect(controller.stateFor('user_teo').items.length, 1);

      fakeLikeGateway.errorToThrow = null;
      final successErr = await controller.unlikeSpot(
        userId: 'user_teo',
        item: sampleItem,
      );
      expect(successErr, isNull);
      expect(controller.stateFor('user_teo').items, isEmpty);
      expect(fakeLikeGateway.toggledSpotIds, ['spot_kyaru', 'spot_kyaru']);
    });
  });

  group('LikedSpotsTab widget tests', () {
    testWidgets('shows loading grid, then error state with retry into success grid',
        (tester) async {
      final completer = Completer<void>();
      final fakeLikedGateway = FakeLikedSpotsGateway(
        completer: completer,
        errorToThrow: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      final fakeLikeGateway = FakeProfileSpotLikeGateway();
      LikedSpotItem? tappedSpot;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            likedSpotsGatewayProvider.overrideWithValue(fakeLikedGateway),
            spotLikeGatewayProvider.overrideWithValue(fakeLikeGateway),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LikedSpotsTab(
                userId: 'user_teo',
                onSpotTap: (item) => tappedSpot = item,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('liked_spots_loading_grid')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải danh sách yêu thích'), findsOneWidget);
      expect(find.textContaining('chưa có quyền'), findsOneWidget);
      expect(find.textContaining('cloud_firestore/'), findsNothing);

      fakeLikedGateway.completer = null;
      fakeLikedGateway.errorToThrow = null;
      fakeLikedGateway.items = const [
        LikedSpotItem(
          id: 'spot_kyaru',
          title: 'Lâu đài Kyaru',
          category: 'Di tích / Văn hóa',
          thumbnailUrl: '',
          authorId: 'author_tan',
          authorName: 'Tấn',
          likesCount: 3,
          ratingAvg: 3.5,
          ratingCount: 2,
        ),
      ];

      await tester.tap(find.byKey(const Key('liked_spots_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('liked_spots_grid')), findsOneWidget);
      expect(find.text('Lâu đài Kyaru'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('liked_spot_card_spot_kyaru')));
      await tester.pump();
      expect(tappedSpot?.id, 'spot_kyaru');
    });

    testWidgets(
        'renders empty state with explore CTA and supports Dark Mode compact 5.5 inch viewport',
        (tester) async {
      final fakeLikedGateway = FakeLikedSpotsGateway(items: const []);
      var explored = false;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            likedSpotsGatewayProvider.overrideWithValue(fakeLikedGateway),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: LikedSpotsTab(
                userId: 'user_teo',
                onExploreTap: () => explored = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có địa điểm yêu thích nào'), findsOneWidget);

      await tester.tap(find.byKey(const Key('liked_spots_explore_button')));
      await tester.pump();
      expect(explored, isTrue);
    });
  });
}