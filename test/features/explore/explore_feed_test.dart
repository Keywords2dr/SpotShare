import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/explore/data/explore_feed_repository.dart';
import 'package:spotshare/features/explore/presentation/explore_feed_controller.dart';
import 'package:spotshare/features/explore/presentation/explore_feed_screen.dart';
import 'package:spotshare/features/explore/presentation/widgets/compact_explore_header.dart';

class _TestExploreUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'user_1';

  void setUid(String? uid) => state = uid;
}

final _testExploreUidProvider =
    NotifierProvider<_TestExploreUidNotifier, String?>(
  _TestExploreUidNotifier.new,
);

class FakeExploreFeedGateway implements ExploreFeedGateway {
  FakeExploreFeedGateway({
    this.pages = const [],
    this.users = const [],
    Map<String, ExploreSpotSummary?>? latestSpotsById,
    this.errorToThrow,
    this.completer,
  }) : latestSpotsById = latestSpotsById ?? <String, ExploreSpotSummary?>{};

  final StreamController<List<ExploreSpotSummary>> _liveController =
      StreamController<List<ExploreSpotSummary>>.broadcast();

  List<ExploreFeedPage> pages;
  List<ExploreUserHit> users;
  final Map<String, ExploreSpotSummary?> latestSpotsById;
  Object? errorToThrow;
  Completer<void>? completer;
  int fetchCalls = 0;
  int watchCalls = 0;
  final List<String> fetchedSpotIds = [];

  bool get hasLiveListeners => _liveController.hasListener;

  void emitLiveHead(List<ExploreSpotSummary> items) {
    if (!_liveController.isClosed) {
      _liveController.add(items);
    }
  }

  void dispose() {
    _liveController.close();
  }

  @override
  Stream<List<ExploreSpotSummary>> watchLatestSpots({int limit = 12}) {
    watchCalls++;
    return _liveController.stream;
  }

  @override
  Future<ExploreFeedPage> fetchPage({
    int limit = 12,
    Object? cursor,
  }) async {
    fetchCalls++;
    if (completer != null) {
      await completer!.future;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (pages.isEmpty) {
      return const ExploreFeedPage(items: [], hasMore: false);
    }
    final index = cursor is int ? cursor : 0;
    if (index >= pages.length) {
      return const ExploreFeedPage(items: [], hasMore: false);
    }
    return pages[index];
  }

  @override
  Future<ExploreSpotSummary?> fetchSpotById(String spotId) async {
    fetchedSpotIds.add(spotId);
    if (latestSpotsById.containsKey(spotId)) {
      return latestSpotsById[spotId];
    }
    for (final page in pages) {
      for (final item in page.items) {
        if (item.id == spotId) return item;
      }
    }
    return null;
  }

  @override
  Future<List<ExploreUserHit>> searchUsersByHandle(String rawHandle) async {
    final normalized = rawHandle.toLowerCase();
    return users
        .where((u) => u.username.toLowerCase().contains(normalized))
        .toList();
  }
}

List<ExploreSpotSummary> _sampleSpots({DateTime? referenceTime}) {
  final now = referenceTime ?? DateTime.now();
  return [
    ExploreSpotSummary(
      id: 'spot_1',
      title: 'Lâu đài Kyaru',
      description: 'Ngắm mèo siêu thư giãn',
      category: 'Di tích / Văn hóa',
      thumbnailUrl: '',
      addressText: 'Hương Lộ 2, TP.HCM',
      bestTimeTag: 'Cả ngày',
      difficultyTag: 'Xe máy',
      priceTag: '> 150k',
      authorId: 'u1',
      authorName: 'Tấn',
      likesCount: 0,
      ratingAvg: 3.5,
      ratingCount: 2,
      createdAt: now.subtract(const Duration(hours: 4)),
    ),
    ExploreSpotSummary(
      id: 'spot_2',
      title: 'Cung đường biển Quy Nhơn',
      description: 'Bãi biển xanh ngắt và cung đèo ngắm hoàng hôn',
      category: 'Bãi biển',
      thumbnailUrl: '',
      addressText: 'Nhơn Lý, Quy Nhơn',
      bestTimeTag: 'Hoàng hôn',
      difficultyTag: 'Xe máy',
      priceTag: 'Miễn phí',
      authorId: 'u2',
      authorName: 'Vũ',
      likesCount: 12,
      ratingAvg: 4.5,
      ratingCount: 2,
      createdAt: now.subtract(const Duration(hours: 18)),
    ),
    ExploreSpotSummary(
      id: 'spot_3',
      title: 'Chùa Ông Núi',
      description: 'Chùa',
      category: 'Cảnh đẹp / Check-in',
      thumbnailUrl: '',
      addressText: 'Cát Tiến, Gia Lai',
      bestTimeTag: 'Sáng sớm (5h-8h)',
      difficultyTag: 'Xe máy',
      priceTag: '< 50k',
      authorId: 'u2',
      authorName: 'Teo Em',
      likesCount: 0,
      ratingAvg: 0.0,
      ratingCount: 0,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

void main() {
  group('ExploreFeedLogic & model unit tests', () {
    test(
        'normalizes Vietnamese accents, merges lists without duplicates, and computes responsive layout',
        () {
      final spots = _sampleSpots();
      final merged = ExploreFeedLogic.mergeHeadAndOlder(
        head: [spots[0], spots[1]],
        older: [spots[1], spots[2]],
      );
      expect(merged.map((e) => e.id).toList(), ['spot_1', 'spot_2', 'spot_3']);

      expect(ExploreFeedLogic.resolveGridCrossAxisCount(360), 2);
      expect(ExploreFeedLogic.resolveGridCrossAxisCount(800), 3);
      expect(ExploreFeedLogic.resolveGridCrossAxisCount(1024), 4);
      expect(
        ExploreFeedLogic.resolveCardMainAxisExtent(1.3),
        greaterThan(ExploreFeedLogic.resolveCardMainAxisExtent(1.0)),
      );

      expect(ExploreFeedLogic.normalizeText('Chùa Ông Núi'), 'chua ong nui');
      expect(ExploreFeedLogic.matchesQuery('chua ong nui', spots[2]), isTrue);
      expect(ExploreFeedLogic.matchesQuery('quy nhon', spots[1]), isTrue);
      expect(ExploreFeedLogic.matchesQuery('da lat', spots[1]), isFalse);
    });

    test(
        'boosts freshly published and pending-timestamp spots in recommendations',
        () {
      final now = DateTime(2026, 11, 22, 1, 30);
      final spots = _sampleSpots(referenceTime: now);
      final freshSpot = ExploreSpotSummary(
        id: 'spot_fresh',
        title: 'Landmark 81 về đêm',
        description: 'Mới đăng',
        category: 'Cảnh đẹp / Check-in',
        thumbnailUrl: '',
        addressText: 'TP.HCM',
        bestTimeTag: 'Tối',
        difficultyTag: 'Xe máy',
        priceTag: 'Miễn phí',
        authorId: 'u2',
        authorName: 'Teo Em',
        likesCount: 0,
        ratingAvg: 0,
        ratingCount: 0,
        createdAt: now.subtract(const Duration(minutes: 2)),
      );
      final pendingTimestampSpot = freshSpot.copyWith(createdAt: null);

      final popularScore =
          ExploreFeedLogic.recommendationScore(spots[1], now: now);
      final freshScore =
          ExploreFeedLogic.recommendationScore(freshSpot, now: now);
      final pendingScore =
          ExploreFeedLogic.recommendationScore(pendingTimestampSpot, now: now);

      expect(freshScore, greaterThan(popularScore));
      expect(pendingScore, greaterThan(popularScore));
    });

    test('matches full and short categories, price tags, and best time tags',
        () {
      expect(
        ExploreFeedLogic.matchesCategory(
          'Cảnh đẹp / Check-in',
          'Cảnh đẹp / Check-in',
        ),
        isTrue,
      );
      expect(
        ExploreFeedLogic.matchesCategory('Cảnh đẹp / Check-in', 'Cảnh đẹp'),
        isTrue,
      );
      expect(
        ExploreFeedLogic.matchesCategory('Món ăn ngon', 'Ẩm thực'),
        isTrue,
      );
      expect(
        ExploreFeedLogic.matchesCategory('Quán cà phê view đẹp', 'Cafe'),
        isTrue,
      );
      expect(ExploreFeedLogic.matchesPrice('< 50k', '<50k'), isTrue);
      expect(ExploreFeedLogic.matchesPrice('50k - 150k', '50k–150k'), isTrue);
      expect(
        ExploreFeedLogic.matchesBestTime('Sáng', 'Sáng sớm (5h-8h)'),
        isTrue,
      );
    });

    test('parses rating fields and aliases safely from Firestore documents',
        () {
      final rated = ExploreSpotSummary.fromFirestore('s1', {
        'title': 'Chùa Ông Núi',
        'averageRating': 5,
        'reviewsCount': 1,
        'likesCount': 2,
      });
      expect(rated.ratingAvg, 5.0);
      expect(rated.ratingCount, 1);
      expect(rated.hasRating, isTrue);

      final unrated = ExploreSpotSummary.fromFirestore('s2', {
        'title': 'Điểm mới',
        'ratingAvg': 0,
        'ratingCount': 0,
      });
      expect(unrated.hasRating, isFalse);
    });

    test('parses @handle queries and maps Firestore errors cleanly', () {
      expect(ExploreFeedLogic.isHandleQuery('@teoem20_73'), isTrue);
      expect(ExploreFeedLogic.extractHandle('@TeoEm20_73'), 'teoem20_73');
      expect(ExploreFeedLogic.isHandleQuery('teoem'), isFalse);

      final denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final mapped = ExploreFeedErrorMapper.map(denied);
      expect(mapped, contains('chưa có quyền'));
      expect(mapped, isNot(contains('cloud_firestore')));
    });
  });

  group('ExploreFeedController unit tests', () {
    test(
        'skips Firestore calls when signed out and cancels live stream immediately on sign-out',
        () async {
      final sample = _sampleSpots();
      final gateway = FakeExploreFeedGateway(
        pages: [ExploreFeedPage(items: sample, hasMore: false)],
      );
      addTearDown(gateway.dispose);

      final container = ProviderContainer(
        overrides: [
          exploreFeedGatewayProvider.overrideWithValue(gateway),
          exploreCurrentUserIdProvider.overrideWith(
            (ref) => ref.watch(_testExploreUidProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(_testExploreUidProvider.notifier).setUid(null);
      await container.read(exploreFeedControllerProvider.notifier).loadInitial();
      expect(gateway.fetchCalls, 0);
      expect(gateway.watchCalls, 0);
      expect(gateway.hasLiveListeners, isFalse);

      container.read(_testExploreUidProvider.notifier).setUid('user_maianh');
      await container.read(exploreFeedControllerProvider.notifier).loadInitial();
      expect(gateway.fetchCalls, 1);
      expect(gateway.watchCalls, 1);
      expect(gateway.hasLiveListeners, isTrue);

      container.read(_testExploreUidProvider.notifier).setUid(null);
      container.read(exploreFeedControllerProvider);
      expect(gateway.hasLiveListeners, isFalse);
    });

    test(
        'paginates, receives newly created spot in real time, and syncs updated/deleted spots',
        () async {
      final sample = _sampleSpots();
      final gateway = FakeExploreFeedGateway(
        pages: [
          ExploreFeedPage(
            items: [sample[0], sample[1]],
            hasMore: true,
            nextCursor: 1,
          ),
          ExploreFeedPage(
            items: [sample[1], sample[2]],
            hasMore: false,
          ),
        ],
        users: const [
          ExploreUserHit(
            uid: 'uid_teo',
            displayName: 'Teo Em',
            username: 'teoem20_73',
            avatarUrl: '',
          ),
        ],
      );
      addTearDown(gateway.dispose);

      final container = ProviderContainer(
        overrides: [
          exploreFeedGatewayProvider.overrideWithValue(gateway),
          exploreCurrentUserIdProvider.overrideWithValue('user_1'),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(exploreFeedControllerProvider.notifier);
      await controller.loadInitial();
      await controller.loadMore();
      expect(container.read(exploreFeedControllerProvider).spots.length, 3);

      final newlyCreated = ExploreSpotSummary(
        id: 'spot_new_landmark',
        title: 'Landmark 81 về đêm',
        description: 'View thành phố cực đẹp',
        category: 'Cảnh đẹp / Check-in',
        thumbnailUrl: '',
        addressText: 'Bình Thạnh, TP.HCM',
        bestTimeTag: 'Tối',
        difficultyTag: 'Xe máy',
        priceTag: 'Miễn phí',
        authorId: 'u2',
        authorName: 'Teo Em',
        likesCount: 0,
        ratingAvg: 0,
        ratingCount: 0,
        createdAt: DateTime.now(),
      );
      gateway.emitLiveHead([newlyCreated, sample[0], sample[1]]);
      await Future<void>.delayed(Duration.zero);

      final afterCreate = container.read(exploreFeedControllerProvider);
      expect(afterCreate.spots.length, 4);
      expect(afterCreate.visibleSpots.first.id, 'spot_new_landmark');

      gateway.latestSpotsById['spot_3'] = sample[2].copyWith(
        ratingAvg: 5.0,
        ratingCount: 1,
      );
      await controller.syncSpotById('spot_3');
      final updatedChua = container
          .read(exploreFeedControllerProvider)
          .spots
          .firstWhere((s) => s.id == 'spot_3');
      expect(updatedChua.ratingAvg, 5.0);
      expect(updatedChua.ratingCount, 1);

      gateway.latestSpotsById['spot_1'] = null;
      await controller.syncSpotById('spot_1');
      expect(
        container
            .read(exploreFeedControllerProvider)
            .spots
            .any((s) => s.id == 'spot_1'),
        isFalse,
      );

      controller.applyFilters(
        category: 'Bãi biển',
        price: 'Miễn phí',
        bestTime: 'Hoàng hôn',
      );
      final filtered = container.read(exploreFeedControllerProvider);
      expect(filtered.activeFilterCount, 3);
      expect(filtered.visibleSpots.map((s) => s.id).toList(), ['spot_2']);

      controller.clearFilters();
      controller.setSort(CompactExploreSortOption.newest);
      await controller.setSearchQuery('@teoem');
      expect(
        container.read(exploreFeedControllerProvider).matchedUsers.first.uid,
        'uid_teo',
      );
    });
  });

  group('ExploreFeedScreen widget tests', () {
    testWidgets(
        'displays newly published spot immediately without manual refresh and syncs rating on detail return',
        (tester) async {
      final sample = _sampleSpots();
      final gateway = FakeExploreFeedGateway(
        pages: [
          ExploreFeedPage(items: sample, hasMore: false),
        ],
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreFeedGatewayProvider.overrideWithValue(gateway),
            exploreCurrentUserIdProvider.overrideWithValue('user_1'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: ExploreFeedScreen(
              onSpotTap: (spot) async {
                gateway.latestSpotsById[spot.id] = spot.copyWith(
                  ratingAvg: 5.0,
                  ratingCount: 1,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final newSpot = ExploreSpotSummary(
        id: 'spot_new',
        title: 'Landmark 81 về đêm',
        description: 'View ban đêm',
        category: 'Cảnh đẹp / Check-in',
        thumbnailUrl: '',
        addressText: 'TP.HCM',
        bestTimeTag: 'Tối',
        difficultyTag: 'Xe máy',
        priceTag: 'Miễn phí',
        authorId: 'u2',
        authorName: 'Teo Em',
        likesCount: 0,
        ratingAvg: 0,
        ratingCount: 0,
        createdAt: DateTime.now(),
      );
      gateway.emitLiveHead([newSpot, ...sample]);
      await tester.pumpAndSettle();

      expect(find.text('Landmark 81 về đêm'), findsOneWidget);

      final chuaCard = find.byKey(const Key('explore_spot_card_spot_3'));
      await tester.ensureVisible(chuaCard);
      await tester.pumpAndSettle();
      await tester.tap(chuaCard);
      await tester.pumpAndSettle();

      expect(gateway.fetchedSpotIds, ['spot_3']);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('explore_spot_rating_spot_3')))
            .data,
        '5.0',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('explore_spot_reviews_spot_3')))
            .data,
        '1',
      );
    });

    testWidgets(
        'handles error retry and filters by category, price, and time inside filter sheet',
        (tester) async {
      final completer = Completer<void>();
      final sample = _sampleSpots();
      final gateway = FakeExploreFeedGateway(
        completer: completer,
        errorToThrow: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreFeedGatewayProvider.overrideWithValue(gateway),
            exploreCurrentUserIdProvider.overrideWithValue('user_1'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const ExploreFeedScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('explore_loading_skeleton')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải bảng tin'), findsOneWidget);

      gateway.completer = null;
      gateway.errorToThrow = null;
      gateway.pages = [
        ExploreFeedPage(items: sample, hasMore: false),
      ];

      await tester.tap(find.byKey(const Key('explore_retry_button')));
      await tester.pumpAndSettle();
      expect(find.text('Lâu đài Kyaru'), findsOneWidget);

      await tester.tap(find.byKey(const Key('explore_header_filter_button')));
      await tester.pumpAndSettle();

      final categoryChip =
          find.byKey(const Key('explore_filter_category_Bãi biển'));
      await tester.ensureVisible(categoryChip);
      await tester.pumpAndSettle();
      await tester.tap(categoryChip);
      await tester.pump();

      final priceChip = find.byKey(const Key('explore_filter_price_Miễn phí'));
      await tester.ensureVisible(priceChip);
      await tester.pumpAndSettle();
      await tester.tap(priceChip);
      await tester.pump();

      final applyButton = find.byKey(const Key('explore_filter_apply_button'));
      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_active_filter_bar')), findsOneWidget);
      expect(find.text('Cung đường biển Quy Nhơn'), findsOneWidget);
      expect(find.text('Lâu đài Kyaru'), findsNothing);

      await tester.tap(find.byKey(const Key('active_filters_clear_all')));
      await tester.pumpAndSettle();
      expect(find.text('Lâu đài Kyaru'), findsOneWidget);
    });

    testWidgets(
        'searches @username and renders cleanly in Dark Mode on 5.5 inch viewport with 1.3x text scale',
        (tester) async {
      final gateway = FakeExploreFeedGateway(
        pages: [
          ExploreFeedPage(items: _sampleSpots(), hasMore: false),
        ],
        users: const [
          ExploreUserHit(
            uid: 'uid_teo',
            displayName: 'Teo Em',
            username: 'teoem20_73',
            avatarUrl: '',
          ),
        ],
      );
      addTearDown(gateway.dispose);
      ExploreUserHit? tappedUser;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreFeedGatewayProvider.overrideWithValue(gateway),
            exploreCurrentUserIdProvider.overrideWithValue('user_1'),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: CompactUiTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: ExploreFeedScreen(
                onUserTap: (user) => tappedUser = user,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('explore_header_search_field')),
        '@teoem',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_user_hit_uid_teo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('explore_user_hit_uid_teo')));
      await tester.pump();
      expect(tappedUser?.uid, 'uid_teo');
      expect(tester.takeException(), isNull);
    });
  });
}