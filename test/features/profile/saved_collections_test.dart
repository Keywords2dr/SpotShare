import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/profile/data/saved_collections_repository.dart';
import 'package:spotshare/features/profile/presentation/saved_collections_controller.dart';
import 'package:spotshare/features/profile/presentation/widgets/saved_collections_tab.dart';

class _TestSavedUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'user_teo';

  void setUid(String? uid) => state = uid;
}

final _testSavedUidProvider = NotifierProvider<_TestSavedUidNotifier, String?>(
  _TestSavedUidNotifier.new,
);

class FakeSavedCollectionsGateway implements SavedCollectionsGateway {
  FakeSavedCollectionsGateway({
    SavedSpotList initialSavedSpots = const [],
    SpotCollectionList initialCollections = const [],
    SavedSpotByIdMap initialAllSpots = const {},
    this.errorOnFetch,
    this.errorOnMutation,
    this.fetchCompleter,
  })  : savedSpots = List<SavedSpotItem>.from(initialSavedSpots),
        collections = List<SpotCollectionModel>.from(initialCollections),
        allSpotsById = {
          ...initialAllSpots,
          for (final s in initialSavedSpots) s.id: s,
        };

  SavedSpotList savedSpots;
  SpotCollectionList collections;
  SavedSpotByIdMap allSpotsById;
  Object? errorOnFetch;
  Object? errorOnMutation;
  Completer<void>? fetchCompleter;
  int _nextColId = 1;

  void _ensureSaved(Iterable<String> spotIds) {
    final existingIds = savedSpots.map((s) => s.id).toSet();
    for (final rawId in spotIds) {
      final id = rawId.trim();
      if (id.isEmpty || existingIds.contains(id)) continue;
      final spot = allSpotsById[id];
      if (spot != null && existingIds.add(id)) {
        savedSpots.insert(0, spot);
      }
    }
  }

  void _deleteSpotsEverywhere(Set<String> spotIds) {
    if (spotIds.isEmpty) return;
    savedSpots.removeWhere((s) => spotIds.contains(s.id));
    collections = collections.map((col) {
      final nextIds =
          col.spotIds.where((id) => !spotIds.contains(id)).toList();
      if (nextIds.length == col.spotIds.length) return col;
      return col.copyWith(spotIds: nextIds, updatedAt: DateTime.now());
    }).toList();
  }

  @override
  Future<SavedCollectionsBundle> fetchSavedBundle({
    required String userId,
    bool cleanupOrphans = false,
  }) async {
    if (fetchCompleter != null) {
      await fetchCompleter!.future;
    }
    if (errorOnFetch != null) {
      throw errorOnFetch!;
    }
    final filteredCollections = collections
        .where((c) => !SavedCollectionsLogic.isReservedCollectionName(c.name))
        .toList();

    final seen = <String>{};
    final mergedSaved = <SavedSpotItem>[];
    for (final spot in savedSpots) {
      if (seen.add(spot.id)) {
        mergedSaved.add(spot);
      }
    }
    for (final col in filteredCollections) {
      for (final spotId in col.spotIds) {
        if (seen.add(spotId)) {
          final spot = allSpotsById[spotId];
          if (spot != null) {
            mergedSaved.add(spot);
          }
        }
      }
    }

    return SavedCollectionsBundle(
      savedSpots: mergedSaved,
      collections: filteredCollections,
      allSpotsById: SavedSpotByIdMap.from(allSpotsById),
    );
  }

  @override
  Future<void> saveSpotToDefault({
    required String userId,
    required String spotId,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    _ensureSaved([spotId]);
  }

  @override
  Future<void> unsaveUncategorizedSpot({
    required String userId,
    required String spotId,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    _deleteSpotsEverywhere({spotId});
  }

  @override
  Future<SpotCollectionModel> createCollection({
    required String userId,
    required String name,
    String description = '',
    String iconKey = 'trip',
    List<String> initialSpotIds = const [],
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    final created = SpotCollectionModel(
      id: 'col_new_${_nextColId++}',
      name: name.trim(),
      description: description.trim(),
      iconKey: iconKey,
      spotIds: List<String>.from(initialSpotIds),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    collections.insert(0, created);
    _ensureSaved(initialSpotIds);
    return created;
  }

  @override
  Future<void> updateCollection({
    required String userId,
    required String collectionId,
    required String name,
    String description = '',
    String iconKey = 'trip',
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    collections = collections.map((col) {
      if (col.id != collectionId) return col;
      return col.copyWith(
        name: name.trim(),
        description: description.trim(),
        iconKey: iconKey,
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> deleteCollection({
    required String userId,
    required String collectionId,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    SpotCollectionModel? target;
    for (final col in collections) {
      if (col.id == collectionId) {
        target = col;
        break;
      }
    }
    collections.removeWhere((col) => col.id == collectionId);
    if (target != null) {
      _deleteSpotsEverywhere(target.spotIds.toSet());
    }
  }

  @override
  Future<void> setCollectionSpots({
    required String userId,
    required String collectionId,
    required List<String> spotIds,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    collections = collections.map((col) {
      if (col.id != collectionId) return col;
      return col.copyWith(
        spotIds: List<String>.from(spotIds),
        updatedAt: DateTime.now(),
      );
    }).toList();
    _ensureSaved(spotIds);
  }

  @override
  Future<void> setSpotCollections({
    required String userId,
    required String spotId,
    required Set<String> targetCollectionIds,
    required SpotCollectionList currentCollections,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    _ensureSaved([spotId]);
    collections = collections.map((col) {
      final shouldHave = targetCollectionIds.contains(col.id);
      final nextIds = shouldHave
          ? (col.spotIds.contains(spotId)
              ? col.spotIds
              : [spotId, ...col.spotIds])
          : col.spotIds.where((id) => id != spotId).toList();
      return col.copyWith(spotIds: nextIds, updatedAt: DateTime.now());
    }).toList();
  }

  @override
  Future<void> removeSpotFromCollection({
    required String userId,
    required String collectionId,
    required String spotId,
    required bool isLastCollection,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    _deleteSpotsEverywhere({spotId});
  }

  @override
  Future<void> saveGeneratedItinerary({
    required String userId,
    required String collectionId,
    required String generatedItinerary,
  }) async {
    if (errorOnMutation != null) throw errorOnMutation!;
    collections = collections.map((col) {
      if (col.id != collectionId) return col;
      return col.copyWith(
        generatedItinerary: generatedItinerary.trim(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }
}

SavedSpotByIdMap _allSpotCatalog() {
  return const {
    'spot_ky_co': SavedSpotItem(
      id: 'spot_ky_co',
      title: 'Bãi biển Kỳ Co',
      category: 'Bãi biển',
      thumbnailUrl: '',
      authorId: 'u1',
      authorName: 'Vũ',
      likesCount: 20,
      ratingAvg: 4.8,
      ratingCount: 6,
      addressText: 'Nhơn Lý, Quy Nhơn',
      priceTag: '50k - 150k',
      latitude: 13.8617,
      longitude: 109.3075,
    ),
    'spot_chua': SavedSpotItem(
      id: 'spot_chua',
      title: 'Chùa Ông Núi',
      category: 'Cảnh đẹp / Check-in',
      thumbnailUrl: '',
      authorId: 'u2',
      authorName: 'Teo Em',
      likesCount: 5,
      ratingAvg: 5.0,
      ratingCount: 1,
      addressText: 'Cát Tiến, Gia Lai',
      priceTag: '< 50k',
      latitude: 13.95309,
      longitude: 109.23453,
    ),
    'spot_banh_xeo': SavedSpotItem(
      id: 'spot_banh_xeo',
      title: 'Bánh xèo tôm nhảy Gia Vỹ',
      category: 'Món ăn ngon',
      thumbnailUrl: '',
      authorId: 'u3',
      authorName: 'Tấn',
      likesCount: 14,
      ratingAvg: 4.6,
      ratingCount: 4,
      addressText: 'Quy Nhơn',
      priceTag: '< 50k',
      latitude: 13.7765,
      longitude: 109.2236,
    ),
    'spot_eo_gio': SavedSpotItem(
      id: 'spot_eo_gio',
      title: 'Eo Gió Quy Nhơn',
      category: 'Cảnh đẹp / Check-in',
      thumbnailUrl: '',
      authorId: 'u1',
      authorName: 'Vũ',
      likesCount: 18,
      ratingAvg: 4.9,
      ratingCount: 8,
      addressText: 'Nhơn Lý, Quy Nhơn',
      priceTag: '< 50k',
      latitude: 13.8752,
      longitude: 109.3011,
    ),
  };
}

SpotCollectionList _sampleCollections() {
  return [
    SpotCollectionModel(
      id: 'col_weekend',
      name: 'Du lịch cuối tuần',
      description: 'Đi 2 ngày 1 đêm bằng xe máy',
      iconKey: 'beach',
      spotIds: const ['spot_ky_co', 'spot_chua'],
      updatedAt: DateTime(2026, 11, 22, 5, 0),
    ),
    SpotCollectionModel(
      id: 'col_food',
      name: 'Quán ngon nhất định thử',
      iconKey: 'food',
      spotIds: const ['spot_ky_co'],
      updatedAt: DateTime(2026, 11, 21, 18, 0),
    ),
  ];
}

void main() {
  group('SavedCollectionsLogic & model unit tests', () {
    test(
        'validates names/descriptions, blocks reserved "Đã lưu" and duplicates, and chunks >10 IDs',
        () {
      final existing = _sampleCollections();
      expect(SavedCollectionsLogic.validateCollectionName(''), isNotNull);
      expect(
        SavedCollectionsLogic.validateCollectionName('Đã lưu'),
        contains('mặc định'),
      );
      expect(
        SavedCollectionsLogic.validateCollectionName('  da luu  '),
        contains('mặc định'),
      );
      expect(
        SavedCollectionsLogic.isReservedCollectionName('Đã Lưu'),
        isTrue,
      );
      expect(
        SavedCollectionsLogic.validateCollectionName('a' * 51),
        contains('tối đa 50'),
      );
      expect(
        SavedCollectionsLogic.validateDescription('b' * 151),
        contains('tối đa 150'),
      );
      expect(
        SavedCollectionsLogic.validateCollectionName(
          'du lich cuoi tuan',
          existing: existing,
        ),
        contains('trùng tên'),
      );
      expect(
        SavedCollectionsLogic.validateCollectionName(
          'Du lịch cuối tuần',
          existing: existing,
          excludingCollectionId: 'col_weekend',
        ),
        isNull,
      );

      final ids = [for (var i = 1; i <= 22; i++) 's_$i', 's_1', ''];
      final chunks = SavedCollectionsLogic.chunkSpotIds(ids);
      expect(chunks.length, 3);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 10);
      expect(chunks[2].length, 2);
    });

    test('parses GPS coordinates safely and evaluates FR-22 AI readiness', () {
      final valid = SavedSpotItem.fromFirestore('s1', {
        'title': 'Kỳ Co',
        'latitude': 13.8617,
        'longitude': 109.3075,
      });
      expect(valid.hasValidCoordinates, isTrue);

      final invalid = SavedSpotItem.fromFirestore('s2', {
        'title': 'Sai GPS',
        'latitude': double.nan,
        'longitude': 200,
      });
      expect(invalid.hasValidCoordinates, isFalse);

      expect(SavedCollectionsLogic.evaluateAiReadiness(2).isReady, isFalse);
      expect(SavedCollectionsLogic.evaluateAiReadiness(4).isReady, isTrue);
      expect(
        SavedCollectionsLogic.evaluateAiReadiness(10).statusMessage,
        contains('8 điểm'),
      );
    });

    test('maps Firestore errors cleanly without raw codes', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final mapped = SavedCollectionsErrorMapper.map(err);
      expect(mapped, contains('chưa có quyền'));
      expect(mapped, isNot(contains('cloud_firestore')));
    });
  });

  group('SavedCollectionsController business rules unit tests', () {
    test(
        'treats Đã lưu as master list of all saved spots and cascade-deletes across Saved and all Collections',
        () async {
      final catalog = _allSpotCatalog();
      final gateway = FakeSavedCollectionsGateway(
        initialSavedSpots: [catalog['spot_banh_xeo']!],
        initialCollections: [
          ..._sampleCollections(),
          const SpotCollectionModel(
            id: 'col_stray_saved',
            name: 'Đã lưu',
            spotIds: ['spot_banh_xeo'],
          ),
        ],
        initialAllSpots: catalog,
      );
      final container = ProviderContainer(
        overrides: [
          savedCollectionsGatewayProvider.overrideWithValue(gateway),
          savedCollectionsCurrentUserIdProvider.overrideWith(
            (ref) => ref.watch(_testSavedUidProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(savedCollectionsControllerProvider.notifier);
      await controller.load(userId: 'user_teo');

      var view = controller.stateFor('user_teo');
      expect(
        view.collections.any((c) => c.name == 'Đã lưu'),
        isFalse,
      );
      expect(
        view.savedSpots.map((s) => s.id).toSet(),
        {'spot_banh_xeo', 'spot_ky_co', 'spot_chua'},
      );
      expect(view.isSpotInDefaultSaved('spot_ky_co'), isTrue);
      expect(view.isSpotSavedAnywhere('spot_ky_co'), isTrue);

      final reservedRes = await controller.createCollection(
        userId: 'user_teo',
        name: 'Đã lưu',
      );
      expect(reservedRes.success, isFalse);
      expect(reservedRes.errorMessage, contains('mặc định'));

      await controller.saveSpotToDefault(
        userId: 'user_teo',
        spot: catalog['spot_eo_gio']!,
      );
      view = controller.stateFor('user_teo');
      expect(view.isSpotInDefaultSaved('spot_eo_gio'), isTrue);
      expect(view.isSpotInAnyCollection('spot_eo_gio'), isFalse);

      await controller.setSpotCollections(
        userId: 'user_teo',
        spotId: 'spot_eo_gio',
        targetCollectionIds: const {'col_weekend'},
      );
      view = controller.stateFor('user_teo');
      expect(view.isSpotInDefaultSaved('spot_eo_gio'), isTrue);
      expect(
        view.collectionsContainingSpot('spot_eo_gio').map((c) => c.id).toList(),
        ['col_weekend'],
      );

      final unsaveFromSaved = await controller.unsaveUncategorizedSpot(
        userId: 'user_teo',
        spotId: 'spot_eo_gio',
      );
      expect(unsaveFromSaved.success, isTrue);
      view = controller.stateFor('user_teo');
      expect(view.isSpotSavedAnywhere('spot_eo_gio'), isFalse);
      expect(view.collectionsContainingSpot('spot_eo_gio'), isEmpty);

      final removeFromCollection = await controller.removeSpotFromCollection(
        userId: 'user_teo',
        collectionId: 'col_weekend',
        spotId: 'spot_ky_co',
      );
      expect(removeFromCollection.success, isTrue);
      expect(removeFromCollection.remainingCollectionCount, 0);
      view = controller.stateFor('user_teo');
      expect(view.isSpotSavedAnywhere('spot_ky_co'), isFalse);
      expect(view.collectionsContainingSpot('spot_ky_co'), isEmpty);

      final deleteColRes = await controller.deleteCollection(
        userId: 'user_teo',
        collectionId: 'col_weekend',
      );
      expect(deleteColRes.success, isTrue);
      view = controller.stateFor('user_teo');
      expect(view.collections.any((c) => c.id == 'col_weekend'), isFalse);
      expect(view.isSpotSavedAnywhere('spot_chua'), isFalse);
      expect(view.isSpotInDefaultSaved('spot_banh_xeo'), isTrue);

      container.read(_testSavedUidProvider.notifier).setUid(null);
      expect(container.read(savedCollectionsControllerProvider), isEmpty);
    });
  });

  group('SavedCollectionsTab widget tests', () {
    testWidgets(
        'shows all saved spots including collection items, keeps spot in Đã lưu after categorizing, and cascade-deletes on confirm',
        (tester) async {
      final catalog = _allSpotCatalog();
      final gateway = FakeSavedCollectionsGateway(
        initialSavedSpots: [catalog['spot_banh_xeo']!],
        initialCollections: _sampleCollections(),
        initialAllSpots: catalog,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedCollectionsGatewayProvider.overrideWithValue(gateway),
            savedCollectionsCurrentUserIdProvider.overrideWithValue('user_teo'),
          ],
          child: MaterialApp(
            theme: CompactUiTheme.light(),
            home: const Scaffold(
              body: SavedCollectionsTab(userId: 'user_teo'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đã lưu 3'), findsOneWidget);
      expect(find.text('Bộ sưu tập 2'), findsOneWidget);
      expect(find.text('Bánh xèo tôm nhảy Gia Vỹ'), findsOneWidget);
      expect(find.text('Bãi biển Kỳ Co'), findsOneWidget);

      final assignChip =
          find.byKey(const Key('saved_spot_assign_chip_spot_banh_xeo'));
      await tester.ensureVisible(assignChip);
      await tester.pumpAndSettle();
      await tester.tap(assignChip);
      await tester.pumpAndSettle();

      expect(find.text('Lưu vào mục Đã lưu'), findsNothing);
      expect(find.text('Xong'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('assign_collection_tile_col_food')),
      );
      await tester.pump();
      expect(find.text('Lưu vào 1 bộ sưu tập'), findsOneWidget);

      await tester.tap(find.byKey(const Key('assign_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Đã lưu 3'), findsOneWidget);
      expect(find.text('Bánh xèo tôm nhảy Gia Vỹ'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('saved_spot_assign_chip_spot_banh_xeo')),
          matching: find.text('1 bộ'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('saved_subtab_collections')));
      await tester.pumpAndSettle();

      final weekendCard = find.byKey(const Key('collection_card_col_weekend'));
      await tester.ensureVisible(weekendCard);
      await tester.pumpAndSettle();
      await tester.tap(weekendCard);
      await tester.pumpAndSettle();

      expect(find.text('2 địa điểm đã chọn'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('collection_remove_spot_spot_ky_co')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xóa địa điểm'), findsOneWidget);
      await tester.tap(find.text('Xóa hết'));
      await tester.pumpAndSettle();

      expect(find.text('1 địa điểm đã chọn'), findsOneWidget);
      expect(
        find.textContaining('khỏi mục Đã lưu và tất cả bộ sưu tập'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Đã lưu 2'), findsOneWidget);
    });

    testWidgets(
        'renders error retry state and displays cleanly on Dark Mode 5.5 inch 1.3x viewport without overflow',
        (tester) async {
      final completer = Completer<void>();
      final catalog = _allSpotCatalog();
      final gateway = FakeSavedCollectionsGateway(
        fetchCompleter: completer,
        errorOnFetch: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedCollectionsGatewayProvider.overrideWithValue(gateway),
            savedCollectionsCurrentUserIdProvider.overrideWithValue('user_teo'),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: CompactUiTheme.dark(),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: SavedCollectionsTab(userId: 'user_teo'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('saved_loading_grid')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved_retry_button')), findsOneWidget);

      gateway.fetchCompleter = null;
      gateway.errorOnFetch = null;
      gateway.savedSpots = [
        catalog['spot_banh_xeo']!,
        catalog['spot_eo_gio']!,
      ];
      gateway.collections = _sampleCollections();
      gateway.allSpotsById = catalog;

      await tester.tap(find.byKey(const Key('saved_retry_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('saved_subtab_collections')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}