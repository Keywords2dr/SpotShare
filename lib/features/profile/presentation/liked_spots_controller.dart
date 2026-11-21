import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../spots/presentation/like/spot_like_controller.dart';
import '../data/liked_spots_repository.dart';

typedef LikedSpotsStateByUser = Map<String, LikedSpotsViewState>;

final likedSpotsCurrentUserIdProvider = Provider<String?>((ref) {
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

final likedSpotsGatewayProvider = Provider<LikedSpotsGateway>((ref) {
  return FirestoreLikedSpotsRepository();
});

class LikedSpotsViewState {
  const LikedSpotsViewState({
    this.items = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.removingSpotIds = const {},
  });

  final List<LikedSpotItem> items;
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;
  final Set<String> removingSpotIds;

  bool get isInitialLoading => isLoading && !hasLoaded;
  bool get isEmpty =>
      hasLoaded && !isLoading && errorMessage == null && items.isEmpty;

  LikedSpotsViewState copyWith({
    List<LikedSpotItem>? items,
    bool? isLoading,
    bool? hasLoaded,
    String? errorMessage,
    bool clearError = false,
    Set<String>? removingSpotIds,
  }) {
    return LikedSpotsViewState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      removingSpotIds: removingSpotIds ?? this.removingSpotIds,
    );
  }
}

class LikedSpotsController extends Notifier<LikedSpotsStateByUser> {
  String _activeAuthUid = '';

  @override
  LikedSpotsStateByUser build() {
    _activeAuthUid = (ref.watch(likedSpotsCurrentUserIdProvider) ?? '').trim();
    return const {};
  }

  LikedSpotsViewState stateFor(String userId) {
    return state[userId] ?? const LikedSpotsViewState();
  }

  Future<void> load({
    required String userId,
    bool forceRefresh = false,
    bool cleanupOrphans = false,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return;
    }
    if (Firebase.apps.isNotEmpty && _activeAuthUid.isEmpty) {
      return;
    }

    final current = stateFor(cleanUserId);
    if (current.isLoading) {
      return;
    }
    if (current.hasLoaded && !forceRefresh && current.errorMessage == null) {
      return;
    }

    final sessionUid = _activeAuthUid;
    state = {
      ...state,
      cleanUserId: current.copyWith(
        isLoading: true,
        clearError: true,
      ),
    };

    try {
      final items = await ref.read(likedSpotsGatewayProvider).fetchLikedSpots(
            userId: cleanUserId,
            cleanupOrphans: cleanupOrphans,
          );
      if (_activeAuthUid != sessionUid) return;
      state = {
        ...state,
        cleanUserId: current.copyWith(
          items: items,
          isLoading: false,
          hasLoaded: true,
          clearError: true,
          removingSpotIds: const {},
        ),
      };
    } catch (e) {
      if (_activeAuthUid != sessionUid) return;
      final message = LikedSpotsErrorMapper.map(e);
      state = {
        ...state,
        cleanUserId: current.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: message,
        ),
      };
    }
  }

  Future<String?> unlikeSpot({
    required String userId,
    required LikedSpotItem item,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return 'Vui lòng đăng nhập để thực hiện thao tác này.';
    }

    final current = stateFor(cleanUserId);
    if (current.removingSpotIds.contains(item.id)) {
      return null;
    }

    final sessionUid = _activeAuthUid;
    final previousItems = List<LikedSpotItem>.from(current.items);
    final nextItems =
        previousItems.where((entry) => entry.id != item.id).toList();
    final nextRemoving = {...current.removingSpotIds, item.id};

    state = {
      ...state,
      cleanUserId: current.copyWith(
        items: nextItems,
        removingSpotIds: nextRemoving,
      ),
    };

    final outcome =
        await ref.read(spotLikeControllerProvider.notifier).toggleLike(
              spotId: item.id,
              userId: cleanUserId,
              fallbackIsLiked: true,
              fallbackLikesCount: item.likesCount,
              authorId: item.authorId,
            );

    if (_activeAuthUid != sessionUid) return null;

    final latest = stateFor(cleanUserId);
    final clearedRemoving = Set<String>.from(latest.removingSpotIds)
      ..remove(item.id);

    if (outcome.success) {
      state = {
        ...state,
        cleanUserId: latest.copyWith(removingSpotIds: clearedRemoving),
      };
      return null;
    }

    state = {
      ...state,
      cleanUserId: latest.copyWith(
        items: previousItems,
        removingSpotIds: clearedRemoving,
      ),
    };
    return outcome.errorMessage ??
        'Không thể bỏ thích lúc này. Vui lòng thử lại.';
  }

  void clearAll() {
    if (state.isEmpty) {
      return;
    }
    state = const {};
  }
}

final likedSpotsControllerProvider =
    NotifierProvider<LikedSpotsController, LikedSpotsStateByUser>(
  LikedSpotsController.new,
);