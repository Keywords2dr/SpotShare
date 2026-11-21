import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../data/spot_like_repository.dart';

typedef SpotLikeStateMap = Map<String, SpotLikeViewState>;
typedef SpotLikeQuery = ({String spotId, String userId});

final spotLikeCurrentUserIdProvider = Provider<String?>((ref) {
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

final spotLikeGatewayProvider = Provider<SpotLikeGateway>((ref) {
  return FirestoreSpotLikeRepository();
});

final spotIsLikedStreamProvider =
    StreamProvider.family<bool, SpotLikeQuery>((ref, query) {
  if (query.spotId.trim().isEmpty || query.userId.trim().isEmpty) {
    return Stream<bool>.value(false);
  }
  return ref.watch(spotLikeGatewayProvider).watchIsLiked(
        spotId: query.spotId,
        userId: query.userId,
      );
});

class SpotLikeViewState {
  const SpotLikeViewState({
    required this.isLiked,
    required this.likesCount,
    this.isProcessing = false,
  });

  final bool isLiked;
  final int likesCount;
  final bool isProcessing;

  SpotLikeViewState copyWith({
    bool? isLiked,
    int? likesCount,
    bool? isProcessing,
  }) {
    return SpotLikeViewState(
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class SpotLikeActionOutcome {
  const SpotLikeActionOutcome({
    required this.success,
    this.errorMessage,
    this.ignored = false,
    this.reachedMilestone,
  });

  final bool success;
  final String? errorMessage;
  final bool ignored;
  final int? reachedMilestone;
}

class SpotLikeController extends Notifier<SpotLikeStateMap> {
  String _activeAuthUid = '';

  @override
  SpotLikeStateMap build() {
    _activeAuthUid = (ref.watch(spotLikeCurrentUserIdProvider) ?? '').trim();
    return const {};
  }

  void syncFromServer({
    required String spotId,
    required bool isLiked,
    required int likesCount,
  }) {
    final existing = state[spotId];
    if (existing != null && existing.isProcessing) {
      return;
    }

    final safeCount = likesCount < 0 ? 0 : likesCount;
    if (existing != null &&
        existing.isLiked == isLiked &&
        existing.likesCount == safeCount) {
      return;
    }

    state = {
      ...state,
      spotId: SpotLikeViewState(
        isLiked: isLiked,
        likesCount: safeCount,
      ),
    };
  }

  void clearAll() {
    if (state.isEmpty) {
      return;
    }
    state = const {};
  }

  Future<SpotLikeActionOutcome> toggleLike({
    required String spotId,
    required String userId,
    required bool fallbackIsLiked,
    required int fallbackLikesCount,
    String? authorId,
  }) async {
    final current = state[spotId] ??
        SpotLikeViewState(
          isLiked: fallbackIsLiked,
          likesCount: fallbackLikesCount < 0 ? 0 : fallbackLikesCount,
        );

    if (current.isProcessing) {
      return const SpotLikeActionOutcome(success: false, ignored: true);
    }

    final sessionUid = _activeAuthUid;
    final nextIsLiked = !current.isLiked;
    final optimisticCount = SpotLikeLogic.computeNextCount(
      currentCount: current.likesCount,
      willLike: nextIsLiked,
    );

    state = {
      ...state,
      spotId: SpotLikeViewState(
        isLiked: nextIsLiked,
        likesCount: optimisticCount,
        isProcessing: true,
      ),
    };

    try {
      final result = await ref.read(spotLikeGatewayProvider).toggleLike(
            spotId: spotId,
            userId: userId,
            authorId: authorId,
          );

      if (_activeAuthUid != sessionUid) {
        return const SpotLikeActionOutcome(success: false, ignored: true);
      }

      state = {
        ...state,
        spotId: SpotLikeViewState(
          isLiked: result.isLiked,
          likesCount: result.likesCount < 0 ? 0 : result.likesCount,
          isProcessing: false,
        ),
      };

      return SpotLikeActionOutcome(
        success: true,
        reachedMilestone: result.reachedMilestone,
      );
    } catch (e) {
      if (_activeAuthUid != sessionUid) {
        return const SpotLikeActionOutcome(success: false, ignored: true);
      }
      state = {
        ...state,
        spotId: current.copyWith(isProcessing: false),
      };
      final message = e.toString().replaceFirst('Exception: ', '');
      return SpotLikeActionOutcome(
        success: false,
        errorMessage: message,
      );
    }
  }
}

final spotLikeControllerProvider =
    NotifierProvider<SpotLikeController, SpotLikeStateMap>(
  SpotLikeController.new,
);