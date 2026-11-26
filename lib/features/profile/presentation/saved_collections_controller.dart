import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/saved_collections_repository.dart';

typedef SavedCollectionsStateByUser = Map<String, SavedCollectionsViewState>;

enum SavedSubTab { allSpots, collections }

final savedCollectionsCurrentUserIdProvider = Provider<String?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => FirebaseAuth.instance.currentUser?.uid,
    error: (_, _) => FirebaseAuth.instance.currentUser?.uid,
  );
});

final savedCollectionsGatewayProvider = Provider<SavedCollectionsGateway>((ref) {
  return FirestoreSavedCollectionsRepository();
});

class SavedCollectionsViewState {
  const SavedCollectionsViewState({
    this.savedSpots = const [],
    this.collections = const [],
    this.allSpotsById = const {},
    this.isLoading = false,
    this.hasLoaded = false,
    this.isMutating = false,
    this.errorMessage,
    this.activeSubTab = SavedSubTab.allSpots,
    this.searchQuery = '',
    this.isSearchOpen = false,
  });

  final SavedSpotList savedSpots;
  final SpotCollectionList collections;
  final SavedSpotByIdMap allSpotsById;
  final bool isLoading;
  final bool hasLoaded;
  final bool isMutating;
  final String? errorMessage;
  final SavedSubTab activeSubTab;
  final String searchQuery;
  final bool isSearchOpen;

  bool get isInitialLoading => isLoading && !hasLoaded;

  SavedSpotByIdMap get spotById {
    return {
      ...allSpotsById,
      for (final spot in savedSpots) spot.id: spot,
    };
  }

  SavedSpotList get allSelectableSpots {
    final seen = <String>{};
    final result = <SavedSpotItem>[];
    for (final spot in savedSpots) {
      if (seen.add(spot.id)) {
        result.add(spot);
      }
    }
    for (final spot in allSpotsById.values) {
      if (seen.add(spot.id)) {
        result.add(spot);
      }
    }
    return result;
  }

  SpotCollectionList collectionsContainingSpot(String spotId) {
    final cleanId = spotId.trim();
    if (cleanId.isEmpty) return const [];
    return collections.where((col) => col.spotIds.contains(cleanId)).toList();
  }

  bool isSpotInAnyCollection(String spotId) {
    return collectionsContainingSpot(spotId).isNotEmpty;
  }

  bool isSpotInDefaultSaved(String spotId) {
    final cleanId = spotId.trim();
    if (cleanId.isEmpty) return false;
    return savedSpots.any((spot) => spot.id == cleanId);
  }

  bool isSpotSavedAnywhere(String spotId) {
    return isSpotInDefaultSaved(spotId) || isSpotInAnyCollection(spotId);
  }

  SavedSpotList get filteredSpots {
    if (searchQuery.trim().isEmpty) return savedSpots;
    return savedSpots
        .where(
          (spot) => SavedCollectionsLogic.matchesSpotQuery(searchQuery, spot),
        )
        .toList();
  }

  SpotCollectionList get filteredCollections {
    if (searchQuery.trim().isEmpty) return collections;
    final map = spotById;
    return collections
        .where(
          (col) => SavedCollectionsLogic.matchesCollectionQuery(
            searchQuery,
            col,
            map,
          ),
        )
        .toList();
  }

  SavedSpotList spotsInCollection(String collectionId) {
    SpotCollectionModel? target;
    for (final col in collections) {
      if (col.id == collectionId) {
        target = col;
        break;
      }
    }
    if (target == null) return const [];
    final map = spotById;
    final result = <SavedSpotItem>[];
    for (final spotId in target.spotIds) {
      final spot = map[spotId];
      if (spot != null) {
        result.add(spot);
      }
    }
    return result;
  }

  SavedCollectionsViewState copyWith({
    SavedSpotList? savedSpots,
    SpotCollectionList? collections,
    SavedSpotByIdMap? allSpotsById,
    bool? isLoading,
    bool? hasLoaded,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
    SavedSubTab? activeSubTab,
    String? searchQuery,
    bool? isSearchOpen,
  }) {
    return SavedCollectionsViewState(
      savedSpots: savedSpots ?? this.savedSpots,
      collections: collections ?? this.collections,
      allSpotsById: allSpotsById ?? this.allSpotsById,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeSubTab: activeSubTab ?? this.activeSubTab,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
    );
  }
}

class SavedCollectionActionResult {
  const SavedCollectionActionResult({
    required this.success,
    this.errorMessage,
    this.createdCollection,
    this.remainingCollectionCount = 0,
  });

  final bool success;
  final String? errorMessage;
  final SpotCollectionModel? createdCollection;
  final int remainingCollectionCount;
}

class SavedCollectionsController extends Notifier<SavedCollectionsStateByUser> {
  String _activeAuthUid = '';

  @override
  SavedCollectionsStateByUser build() {
    _activeAuthUid =
        (ref.watch(savedCollectionsCurrentUserIdProvider) ?? '').trim();
    return const {};
  }

  SavedCollectionsViewState stateFor(String userId) {
    return state[userId] ?? const SavedCollectionsViewState();
  }

  void _updateUser(String userId, SavedCollectionsViewState next) {
    state = {
      ...state,
      userId: next,
    };
  }

  SavedSpotList _ensureSpotsPresent(
    SavedSpotList currentSpots,
    Iterable<String> spotIds,
    SavedSpotByIdMap spotMap,
  ) {
    final existingIds = currentSpots.map((spot) => spot.id).toSet();
    final additions = <SavedSpotItem>[];
    for (final rawId in spotIds) {
      final cleanId = rawId.trim();
      if (cleanId.isEmpty || existingIds.contains(cleanId)) continue;
      final item = spotMap[cleanId];
      if (item != null && existingIds.add(cleanId)) {
        additions.add(item);
      }
    }
    if (additions.isEmpty) return currentSpots;
    return [...additions, ...currentSpots];
  }

  void setSubTab(String userId, SavedSubTab tab) {
    final current = stateFor(userId);
    if (current.activeSubTab == tab) return;
    _updateUser(userId, current.copyWith(activeSubTab: tab));
  }

  void toggleSearch(String userId) {
    final current = stateFor(userId);
    final nextOpen = !current.isSearchOpen;
    _updateUser(
      userId,
      current.copyWith(
        isSearchOpen: nextOpen,
        searchQuery: nextOpen ? current.searchQuery : '',
      ),
    );
  }

  void setSearchQuery(String userId, String query) {
    final current = stateFor(userId);
    if (current.searchQuery == query) return;
    _updateUser(userId, current.copyWith(searchQuery: query));
  }

  Future<void> load({
    required String userId,
    bool forceRefresh = false,
    bool cleanupOrphans = false,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;
    if (Firebase.apps.isNotEmpty && _activeAuthUid.isEmpty) return;

    final current = stateFor(cleanUid);
    if (current.isLoading) return;
    if (current.hasLoaded && !forceRefresh && current.errorMessage == null) {
      return;
    }

    final sessionUid = _activeAuthUid;
    _updateUser(
      cleanUid,
      current.copyWith(isLoading: true, clearError: true),
    );

    try {
      final bundle = await ref
          .read(savedCollectionsGatewayProvider)
          .fetchSavedBundle(
            userId: cleanUid,
            cleanupOrphans: cleanupOrphans,
          );
      if (_activeAuthUid != sessionUid) return;
      final latest = stateFor(cleanUid);
      final mergedMap = <String, SavedSpotItem>{
        ...bundle.allSpotsById,
        for (final spot in bundle.savedSpots) spot.id: spot,
      };
      _updateUser(
        cleanUid,
        latest.copyWith(
          savedSpots: bundle.savedSpots,
          collections: bundle.collections,
          allSpotsById: mergedMap,
          isLoading: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
    } catch (e) {
      if (_activeAuthUid != sessionUid) return;
      final latest = stateFor(cleanUid);
      _updateUser(
        cleanUid,
        latest.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: SavedCollectionsErrorMapper.map(e),
        ),
      );
    }
  }

  Future<SavedCollectionActionResult> saveSpotToDefault({
    required String userId,
    required SavedSpotItem spot,
  }) async {
    final cleanUid = userId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previousSpots = List<SavedSpotItem>.from(current.savedSpots);
    final previousMap = SavedSpotByIdMap.from(current.allSpotsById);

    final alreadySaved = previousSpots.any((item) => item.id == spot.id);
    final nextSpots = alreadySaved
        ? previousSpots
        : [
            spot,
            ...previousSpots,
          ];
    final nextMap = <String, SavedSpotItem>{
      ...previousMap,
      spot.id: spot,
    };

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: nextSpots,
        allSpotsById: nextMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).saveSpotToDefault(
            userId: cleanUid,
            spotId: spot.id,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSpots,
            allSpotsById: previousMap,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> unsaveUncategorizedSpot({
    required String userId,
    required String spotId,
  }) async {
    final cleanUid = userId.trim();
    final cleanSpotId = spotId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previousSpots = List<SavedSpotItem>.from(current.savedSpots);
    final previousCollections =
        List<SpotCollectionModel>.from(current.collections);
    final previousMap = SavedSpotByIdMap.from(current.allSpotsById);

    final nextSpots =
        previousSpots.where((spot) => spot.id != cleanSpotId).toList();
    final now = DateTime.now();
    final nextCollections = previousCollections.map((col) {
      if (!col.spotIds.contains(cleanSpotId)) return col;
      return col.copyWith(
        spotIds: col.spotIds.where((id) => id != cleanSpotId).toList(),
        updatedAt: now,
      );
    }).toList();
    final nextMap = SavedSpotByIdMap.from(previousMap)..remove(cleanSpotId);

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: nextSpots,
        collections: SavedCollectionsLogic.sortCollections(nextCollections),
        allSpotsById: nextMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).unsaveUncategorizedSpot(
            userId: cleanUid,
            spotId: cleanSpotId,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSpots,
            collections: previousCollections,
            allSpotsById: previousMap,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> createCollection({
    required String userId,
    required String name,
    String description = '',
    String iconKey = 'trip',
    List<String> initialSpotIds = const [],
    SavedSpotItem? seedSpot,
  }) async {
    final cleanUid = userId.trim();
    final current = stateFor(cleanUid);
    final nameErr = SavedCollectionsLogic.validateCollectionName(
      name,
      existing: current.collections,
    );
    if (nameErr != null) {
      return SavedCollectionActionResult(success: false, errorMessage: nameErr);
    }
    final descErr = SavedCollectionsLogic.validateDescription(description);
    if (descErr != null) {
      return SavedCollectionActionResult(success: false, errorMessage: descErr);
    }

    final sessionUid = _activeAuthUid;
    _updateUser(cleanUid, current.copyWith(isMutating: true));

    try {
      final created = await ref
          .read(savedCollectionsGatewayProvider)
          .createCollection(
            userId: cleanUid,
            name: name.trim(),
            description: description.trim(),
            iconKey: iconKey,
            initialSpotIds: initialSpotIds,
          );
      if (_activeAuthUid != sessionUid) {
        return const SavedCollectionActionResult(success: false);
      }

      final latest = stateFor(cleanUid);
      final nextAllMap = SavedSpotByIdMap.from(latest.spotById);
      if (seedSpot != null) {
        nextAllMap[seedSpot.id] = seedSpot;
      }
      final nextSavedSpots = _ensureSpotsPresent(
        latest.savedSpots,
        created.spotIds,
        nextAllMap,
      );
      final updatedList = SavedCollectionsLogic.sortCollections([
        created,
        ...latest.collections,
      ]);

      _updateUser(
        cleanUid,
        latest.copyWith(
          savedSpots: nextSavedSpots,
          collections: updatedList,
          allSpotsById: nextAllMap,
          isMutating: false,
        ),
      );
      return SavedCollectionActionResult(
        success: true,
        createdCollection: created,
      );
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        final latest = stateFor(cleanUid);
        _updateUser(cleanUid, latest.copyWith(isMutating: false));
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> updateCollection({
    required String userId,
    required String collectionId,
    required String name,
    String description = '',
    String iconKey = 'trip',
  }) async {
    final cleanUid = userId.trim();
    final current = stateFor(cleanUid);
    final nameErr = SavedCollectionsLogic.validateCollectionName(
      name,
      existing: current.collections,
      excludingCollectionId: collectionId,
    );
    if (nameErr != null) {
      return SavedCollectionActionResult(success: false, errorMessage: nameErr);
    }
    final descErr = SavedCollectionsLogic.validateDescription(description);
    if (descErr != null) {
      return SavedCollectionActionResult(success: false, errorMessage: descErr);
    }

    final sessionUid = _activeAuthUid;
    final previous = List<SpotCollectionModel>.from(current.collections);
    final now = DateTime.now();
    final optimistic = SavedCollectionsLogic.sortCollections(
      previous.map((col) {
        if (col.id != collectionId) return col;
        return col.copyWith(
          name: name.trim(),
          description: description.trim(),
          iconKey: iconKey,
          updatedAt: now,
        );
      }).toList(),
    );

    _updateUser(
      cleanUid,
      current.copyWith(collections: optimistic, isMutating: true),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).updateCollection(
            userId: cleanUid,
            collectionId: collectionId,
            name: name.trim(),
            description: description.trim(),
            iconKey: iconKey,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            collections: previous,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> deleteCollection({
    required String userId,
    required String collectionId,
  }) async {
    final cleanUid = userId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previous = List<SpotCollectionModel>.from(current.collections);
    final previousSavedSpots = List<SavedSpotItem>.from(current.savedSpots);
    final previousMap = SavedSpotByIdMap.from(current.allSpotsById);

    SpotCollectionModel? target;
    for (final col in previous) {
      if (col.id == collectionId) {
        target = col;
        break;
      }
    }

    final removedIds = target?.spotIds.toSet() ?? const <String>{};
    final now = DateTime.now();
    final remaining = previous.where((col) => col.id != collectionId).map((col) {
      if (removedIds.isEmpty) return col;
      final filtered =
          col.spotIds.where((id) => !removedIds.contains(id)).toList();
      if (filtered.length == col.spotIds.length) return col;
      return col.copyWith(spotIds: filtered, updatedAt: now);
    }).toList();

    final nextSavedSpots = previousSavedSpots
        .where((spot) => !removedIds.contains(spot.id))
        .toList();
    final nextMap = SavedSpotByIdMap.from(previousMap)
      ..removeWhere((key, _) => removedIds.contains(key));

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: nextSavedSpots,
        collections: SavedCollectionsLogic.sortCollections(remaining),
        allSpotsById: nextMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).deleteCollection(
            userId: cleanUid,
            collectionId: collectionId,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSavedSpots,
            collections: previous,
            allSpotsById: previousMap,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> setCollectionSpots({
    required String userId,
    required String collectionId,
    required List<String> spotIds,
  }) async {
    final cleanUid = userId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previousCollections =
        List<SpotCollectionModel>.from(current.collections);
    final previousSavedSpots = List<SavedSpotItem>.from(current.savedSpots);
    final spotMap = current.spotById;

    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final id in spotIds) {
      final clean = id.trim();
      if (clean.isNotEmpty && seen.add(clean)) {
        uniqueIds.add(clean);
      }
    }

    final now = DateTime.now();
    final optimisticCollections = SavedCollectionsLogic.sortCollections(
      previousCollections.map((col) {
        if (col.id != collectionId) return col;
        return col.copyWith(spotIds: uniqueIds, updatedAt: now);
      }).toList(),
    );
    final optimisticSavedSpots = _ensureSpotsPresent(
      previousSavedSpots,
      uniqueIds,
      spotMap,
    );

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: optimisticSavedSpots,
        collections: optimisticCollections,
        allSpotsById: spotMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).setCollectionSpots(
            userId: cleanUid,
            collectionId: collectionId,
            spotIds: uniqueIds,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSavedSpots,
            collections: previousCollections,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> setSpotCollections({
    required String userId,
    required String spotId,
    required Set<String> targetCollectionIds,
    SavedSpotItem? spotFallback,
  }) async {
    final cleanUid = userId.trim();
    final cleanSpotId = spotId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previousCollections =
        List<SpotCollectionModel>.from(current.collections);
    final previousSavedSpots = List<SavedSpotItem>.from(current.savedSpots);
    final previousMap = SavedSpotByIdMap.from(current.spotById);

    final resolvedSpot = previousMap[cleanSpotId] ?? spotFallback;
    if (resolvedSpot != null) {
      previousMap[cleanSpotId] = resolvedSpot;
    }

    final now = DateTime.now();
    final optimisticCollections = previousCollections.map((col) {
      final hasSpot = col.spotIds.contains(cleanSpotId);
      final shouldHave = targetCollectionIds.contains(col.id);
      if (hasSpot == shouldHave) return col;
      final nextIds = shouldHave
          ? [cleanSpotId, ...col.spotIds]
          : col.spotIds.where((id) => id != cleanSpotId).toList();
      return col.copyWith(spotIds: nextIds, updatedAt: now);
    }).toList();

    final optimisticSavedSpots = _ensureSpotsPresent(
      previousSavedSpots,
      [cleanSpotId],
      previousMap,
    );

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: optimisticSavedSpots,
        collections:
            SavedCollectionsLogic.sortCollections(optimisticCollections),
        allSpotsById: previousMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).setSpotCollections(
            userId: cleanUid,
            spotId: cleanSpotId,
            targetCollectionIds: targetCollectionIds,
            currentCollections: previousCollections,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(success: true);
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSavedSpots,
            collections: previousCollections,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }

  Future<SavedCollectionActionResult> removeSpotFromCollection({
    required String userId,
    required String collectionId,
    required String spotId,
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    final cleanSpotId = spotId.trim();
    final current = stateFor(cleanUid);
    final sessionUid = _activeAuthUid;
    final previousCollections =
        List<SpotCollectionModel>.from(current.collections);
    final previousSavedSpots = List<SavedSpotItem>.from(current.savedSpots);
    final previousMap = SavedSpotByIdMap.from(current.allSpotsById);

    final now = DateTime.now();
    final nextCollections = previousCollections.map((col) {
      if (!col.spotIds.contains(cleanSpotId)) return col;
      return col.copyWith(
        spotIds: col.spotIds.where((id) => id != cleanSpotId).toList(),
        updatedAt: now,
      );
    }).toList();

    final nextSavedSpots =
        previousSavedSpots.where((s) => s.id != cleanSpotId).toList();
    final nextMap = SavedSpotByIdMap.from(previousMap)..remove(cleanSpotId);

    _updateUser(
      cleanUid,
      current.copyWith(
        savedSpots: nextSavedSpots,
        collections: SavedCollectionsLogic.sortCollections(nextCollections),
        allSpotsById: nextMap,
        isMutating: true,
      ),
    );

    try {
      await ref.read(savedCollectionsGatewayProvider).removeSpotFromCollection(
            userId: cleanUid,
            collectionId: cleanColId,
            spotId: cleanSpotId,
            isLastCollection: true,
          );
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(isMutating: false),
        );
      }
      return const SavedCollectionActionResult(
        success: true,
        remainingCollectionCount: 0,
      );
    } catch (e) {
      if (_activeAuthUid == sessionUid) {
        _updateUser(
          cleanUid,
          stateFor(cleanUid).copyWith(
            savedSpots: previousSavedSpots,
            collections: previousCollections,
            allSpotsById: previousMap,
            isMutating: false,
          ),
        );
      }
      return SavedCollectionActionResult(
        success: false,
        errorMessage: SavedCollectionsErrorMapper.map(e),
      );
    }
  }
}

final savedCollectionsControllerProvider =
    NotifierProvider<SavedCollectionsController, SavedCollectionsStateByUser>(
  SavedCollectionsController.new,
);