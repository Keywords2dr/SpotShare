import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/explore_feed_repository.dart';
import 'widgets/compact_explore_header.dart';

final exploreCurrentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => FirebaseAuth.instance.currentUser?.uid,
    error: (_, _) => FirebaseAuth.instance.currentUser?.uid,
  );
});

final exploreFeedGatewayProvider = Provider<ExploreFeedGateway>((ref) {
  return FirestoreExploreFeedRepository();
});

class ExploreFeedState {
  const ExploreFeedState({
    this.spots = const [],
    this.matchedUsers = const [],
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isSearchingUsers = false,
    this.hasLoaded = false,
    this.hasMore = true,
    this.nextCursor,
    this.errorMessage,
    this.sortOption = CompactExploreSortOption.recommended,
    this.selectedCategory = ExploreFeedFilterPresets.allCategory,
    this.selectedPrice,
    this.selectedBestTime,
    this.searchQuery = '',
  });

  final List<ExploreSpotSummary> spots;
  final List<ExploreUserHit> matchedUsers;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isSearchingUsers;
  final bool hasLoaded;
  final bool hasMore;
  final Object? nextCursor;
  final String? errorMessage;
  final CompactExploreSortOption sortOption;
  final String selectedCategory;
  final String? selectedPrice;
  final String? selectedBestTime;
  final String searchQuery;

  bool get hasActiveCategory =>
      selectedCategory != ExploreFeedFilterPresets.allCategory;

  int get activeFilterCount {
    var count = 0;
    if (hasActiveCategory) count++;
    if (selectedPrice != null && selectedPrice!.trim().isNotEmpty) count++;
    if (selectedBestTime != null && selectedBestTime!.trim().isNotEmpty) {
      count++;
    }
    return count;
  }

  bool get hasAnyCriteria {
    return searchQuery.trim().isNotEmpty || activeFilterCount > 0;
  }

  List<ExploreSpotSummary> get visibleSpots {
    final filtered = spots.where((spot) {
      if (!ExploreFeedLogic.matchesCategory(selectedCategory, spot.category)) {
        return false;
      }
      if (!ExploreFeedLogic.matchesPrice(selectedPrice, spot.priceTag)) {
        return false;
      }
      if (!ExploreFeedLogic.matchesBestTime(
        selectedBestTime,
        spot.bestTimeTag,
      )) {
        return false;
      }
      if (!ExploreFeedLogic.matchesQuery(searchQuery, spot)) {
        return false;
      }
      return true;
    }).toList();

    final now = DateTime.now();
    if (sortOption == CompactExploreSortOption.newest) {
      filtered.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return bTime.compareTo(aTime);
      });
    } else {
      filtered.sort((a, b) {
        final scoreCompare = ExploreFeedLogic.recommendationScore(b, now: now)
            .compareTo(ExploreFeedLogic.recommendationScore(a, now: now));
        if (scoreCompare != 0) return scoreCompare;
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return bTime.compareTo(aTime);
      });
    }

    return filtered;
  }

  ExploreFeedState copyWith({
    List<ExploreSpotSummary>? spots,
    List<ExploreUserHit>? matchedUsers,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isSearchingUsers,
    bool? hasLoaded,
    bool? hasMore,
    Object? nextCursor,
    bool clearCursor = false,
    String? errorMessage,
    bool clearError = false,
    CompactExploreSortOption? sortOption,
    String? selectedCategory,
    String? selectedPrice,
    bool clearPrice = false,
    String? selectedBestTime,
    bool clearBestTime = false,
    String? searchQuery,
  }) {
    return ExploreFeedState(
      spots: spots ?? this.spots,
      matchedUsers: matchedUsers ?? this.matchedUsers,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSearchingUsers: isSearchingUsers ?? this.isSearchingUsers,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sortOption: sortOption ?? this.sortOption,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedPrice: clearPrice ? null : (selectedPrice ?? this.selectedPrice),
      selectedBestTime: clearBestTime
          ? null
          : (selectedBestTime ?? this.selectedBestTime),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ExploreFeedController extends Notifier<ExploreFeedState> {
  static const int pageSize = 12;

  StreamSubscription<List<ExploreSpotSummary>>? _liveSub;
  List<ExploreSpotSummary> _liveHeadSpots = const [];
  List<ExploreSpotSummary> _olderSpots = const [];
  bool _hasReceivedLiveHead = false;
  int _userSearchSeq = 0;
  String _activeUserId = '';

  bool get _hasActiveSession => _activeUserId.isNotEmpty;

  @override
  ExploreFeedState build() {
    final uid = ref.watch(exploreCurrentUserIdProvider);
    _activeUserId = (uid ?? '').trim();

    _liveSub?.cancel();
    _liveSub = null;
    _liveHeadSpots = const [];
    _olderSpots = const [];
    _hasReceivedLiveHead = false;
    _userSearchSeq++;

    ref.onDispose(() {
      _liveSub?.cancel();
      _liveSub = null;
    });
    return const ExploreFeedState();
  }

  void _ensureLiveSubscription({bool forceRestart = false}) {
    if (!_hasActiveSession) {
      _liveSub?.cancel();
      _liveSub = null;
      return;
    }
    if (_liveSub != null && !forceRestart) return;

    final sessionUid = _activeUserId;
    _liveSub?.cancel();
    _hasReceivedLiveHead = false;

    _liveSub = ref
        .read(exploreFeedGatewayProvider)
        .watchLatestSpots(limit: pageSize)
        .listen(
      (headItems) {
        if (_activeUserId != sessionUid) return;
        _hasReceivedLiveHead = true;
        _liveHeadSpots = headItems;
        final merged = ExploreFeedLogic.mergeHeadAndOlder(
          head: _liveHeadSpots,
          older: _olderSpots,
        );
        state = state.copyWith(
          spots: merged,
          isInitialLoading: false,
          isRefreshing: false,
          hasLoaded: true,
          clearError: true,
        );
      },
      onError: (Object error) {
        if (_activeUserId != sessionUid || !_hasActiveSession) {
          _liveSub?.cancel();
          _liveSub = null;
          return;
        }
        final isTransientAuthLoss =
            error.toString().toLowerCase().contains('permission-denied') &&
                !_isFirebaseSignedIn();
        if (isTransientAuthLoss) {
          _liveSub?.cancel();
          _liveSub = null;
          return;
        }
        if (kDebugMode) {
          debugPrint('[ExploreFeedController] watchLatestSpots error: $error');
        }
      },
    );
  }

  bool _isFirebaseSignedIn() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return _hasActiveSession;
    }
  }

  Future<void> loadInitial({bool force = false}) async {
    if (!_hasActiveSession) return;
    if (state.isInitialLoading) return;
    if (state.hasLoaded && !force && state.errorMessage == null) {
      _ensureLiveSubscription();
      return;
    }

    final sessionUid = _activeUserId;
    if (force) {
      _olderSpots = const [];
    }
    _ensureLiveSubscription(forceRestart: force);

    state = state.copyWith(
      isInitialLoading: state.spots.isEmpty,
      isRefreshing: state.spots.isNotEmpty,
      clearError: true,
    );

    try {
      final page = await ref
          .read(exploreFeedGatewayProvider)
          .fetchPage(limit: pageSize);
      if (_activeUserId != sessionUid) return;

      if (!_hasReceivedLiveHead || _liveHeadSpots.isEmpty) {
        _liveHeadSpots = page.items;
      }
      final merged = ExploreFeedLogic.mergeHeadAndOlder(
        head: _liveHeadSpots,
        older: _olderSpots,
      );

      state = state.copyWith(
        spots: merged,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isInitialLoading: false,
        isRefreshing: false,
        hasLoaded: true,
        clearError: true,
      );
    } catch (e) {
      if (_activeUserId != sessionUid) return;
      state = state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        hasLoaded: true,
        errorMessage: ExploreFeedErrorMapper.map(e),
      );
    }
  }

  Future<void> refresh() => loadInitial(force: true);

  Future<void> syncSpotById(String spotId) async {
    if (!_hasActiveSession) return;
    final cleanId = spotId.trim();
    if (cleanId.isEmpty) return;
    final sessionUid = _activeUserId;

    try {
      final latest =
          await ref.read(exploreFeedGatewayProvider).fetchSpotById(cleanId);
      if (_activeUserId != sessionUid) return;

      if (latest == null) {
        _liveHeadSpots =
            _liveHeadSpots.where((s) => s.id != cleanId).toList();
        _olderSpots = _olderSpots.where((s) => s.id != cleanId).toList();
        state = state.copyWith(
          spots: ExploreFeedLogic.mergeHeadAndOlder(
            head: _liveHeadSpots,
            older: _olderSpots,
          ),
        );
        return;
      }

      var replaced = false;
      _liveHeadSpots = _liveHeadSpots.map((spot) {
        if (spot.id == cleanId) {
          replaced = true;
          return latest;
        }
        return spot;
      }).toList();

      _olderSpots = _olderSpots.map((spot) {
        if (spot.id == cleanId) {
          replaced = true;
          return latest;
        }
        return spot;
      }).toList();

      if (!replaced && state.hasLoaded) {
        _liveHeadSpots = [latest, ..._liveHeadSpots];
      }

      state = state.copyWith(
        spots: ExploreFeedLogic.mergeHeadAndOlder(
          head: _liveHeadSpots,
          older: _olderSpots,
        ),
      );
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (!_hasActiveSession) return;
    if (state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }

    final sessionUid = _activeUserId;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await ref.read(exploreFeedGatewayProvider).fetchPage(
            limit: pageSize,
            cursor: state.nextCursor,
          );
      if (_activeUserId != sessionUid) return;

      _olderSpots = ExploreFeedLogic.mergeHeadAndOlder(
        head: _olderSpots,
        older: page.items,
      );
      final merged = ExploreFeedLogic.mergeHeadAndOlder(
        head: _liveHeadSpots,
        older: _olderSpots,
      );

      state = state.copyWith(
        spots: merged,
        hasMore: page.hasMore && page.items.isNotEmpty,
        nextCursor: page.nextCursor ?? state.nextCursor,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      if (_activeUserId != sessionUid) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: ExploreFeedErrorMapper.map(e),
      );
    }
  }

  void setSort(CompactExploreSortOption option) {
    if (state.sortOption == option) return;
    state = state.copyWith(sortOption: option);
  }

  void setCategory(String category) {
    final normalized = category.trim().isEmpty
        ? ExploreFeedFilterPresets.allCategory
        : category.trim();
    if (state.selectedCategory == normalized) return;
    state = state.copyWith(selectedCategory: normalized);
  }

  void applyFilters({
    String? category,
    String? price,
    String? bestTime,
  }) {
    final normalizedCategory =
        (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : ExploreFeedFilterPresets.allCategory;
    final normalizedPrice =
        (price != null && price.trim().isNotEmpty) ? price.trim() : null;
    final normalizedTime = (bestTime != null && bestTime.trim().isNotEmpty)
        ? bestTime.trim()
        : null;

    state = state.copyWith(
      selectedCategory: normalizedCategory,
      selectedPrice: normalizedPrice,
      clearPrice: normalizedPrice == null,
      selectedBestTime: normalizedTime,
      clearBestTime: normalizedTime == null,
    );
  }

  void clearFilters({bool clearQuery = false}) {
    state = state.copyWith(
      selectedCategory: ExploreFeedFilterPresets.allCategory,
      clearPrice: true,
      clearBestTime: true,
      searchQuery: clearQuery ? '' : state.searchQuery,
      matchedUsers: clearQuery ? const [] : state.matchedUsers,
      isSearchingUsers: clearQuery ? false : state.isSearchingUsers,
    );
  }

  Future<void> setSearchQuery(String rawQuery) async {
    final query = rawQuery;
    final isHandle = ExploreFeedLogic.isHandleQuery(query);
    final handle = ExploreFeedLogic.extractHandle(query);

    if (!isHandle || handle.isEmpty || !_hasActiveSession) {
      _userSearchSeq++;
      state = state.copyWith(
        searchQuery: query,
        matchedUsers: const [],
        isSearchingUsers: false,
      );
      return;
    }

    final seq = ++_userSearchSeq;
    final sessionUid = _activeUserId;
    state = state.copyWith(
      searchQuery: query,
      isSearchingUsers: true,
    );

    try {
      final users = await ref
          .read(exploreFeedGatewayProvider)
          .searchUsersByHandle(handle);
      if (seq != _userSearchSeq || _activeUserId != sessionUid) return;
      state = state.copyWith(
        matchedUsers: users,
        isSearchingUsers: false,
      );
    } catch (_) {
      if (seq != _userSearchSeq || _activeUserId != sessionUid) return;
      state = state.copyWith(
        matchedUsers: const [],
        isSearchingUsers: false,
      );
    }
  }
}

final exploreFeedControllerProvider =
    NotifierProvider<ExploreFeedController, ExploreFeedState>(
  ExploreFeedController.new,
);