import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/spot_review_repository.dart';

typedef ReviewComposerStateMap = Map<String, ReviewComposerState>;

final spotReviewCurrentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => FirebaseAuth.instance.currentUser?.uid,
    error: (_, _) => FirebaseAuth.instance.currentUser?.uid,
  );
});

final spotReviewGatewayProvider = Provider<SpotReviewGateway>((ref) {
  return FirestoreSpotReviewRepository();
});

final spotReviewsStreamProvider =
    StreamProvider.autoDispose.family<ReviewItemList, String>((ref, spotId) {
  return ref.watch(spotReviewGatewayProvider).watchReviews(spotId);
});

class ReviewComposerState {
  const ReviewComposerState({
    this.replyingTo,
    this.isSubmitting = false,
    this.focusRequestId = 0,
  });

  final SpotReviewItem? replyingTo;
  final bool isSubmitting;
  final int focusRequestId;

  bool get isReplying => replyingTo != null;

  ReviewComposerState copyWith({
    SpotReviewItem? replyingTo,
    bool clearReplyTarget = false,
    bool? isSubmitting,
    int? focusRequestId,
  }) {
    return ReviewComposerState(
      replyingTo: clearReplyTarget ? null : (replyingTo ?? this.replyingTo),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      focusRequestId: focusRequestId ?? this.focusRequestId,
    );
  }
}

class ReviewActionResult {
  const ReviewActionResult({
    required this.success,
    this.errorMessage,
    this.ignored = false,
  });

  final bool success;
  final String? errorMessage;
  final bool ignored;
}

class SpotReviewController extends Notifier<ReviewComposerStateMap> {
  @override
  ReviewComposerStateMap build() {
    ref.watch(spotReviewCurrentUserIdProvider);
    return const {};
  }

  ReviewComposerState stateFor(String spotId) {
    return state[spotId] ?? const ReviewComposerState();
  }

  void startReply({
    required String spotId,
    required SpotReviewItem target,
  }) {
    final current = stateFor(spotId);
    state = {
      ...state,
      spotId: current.copyWith(
        replyingTo: target,
        focusRequestId: current.focusRequestId + 1,
      ),
    };
  }

  void cancelReply(String spotId) {
    final current = stateFor(spotId);
    if (!current.isReplying) return;
    state = {
      ...state,
      spotId: current.copyWith(clearReplyTarget: true),
    };
  }

  Future<ReviewActionResult> submitComment({
    required String spotId,
    required String userId,
    required String comment,
    required int rating,
  }) async {
    final current = stateFor(spotId);
    if (current.isSubmitting) {
      return const ReviewActionResult(success: false, ignored: true);
    }

    final validationError = SpotReviewLogic.validateComment(comment);
    if (validationError != null) {
      return ReviewActionResult(success: false, errorMessage: validationError);
    }

    final replyTarget = current.replyingTo;
    state = {
      ...state,
      spotId: current.copyWith(isSubmitting: true),
    };

    try {
      await ref.read(spotReviewGatewayProvider).addReview(
            spotId: spotId,
            userId: userId,
            comment: comment,
            rating: rating,
            replyTo: replyTarget,
          );

      final latest = stateFor(spotId);
      state = {
        ...state,
        spotId: latest.copyWith(
          isSubmitting: false,
          clearReplyTarget: true,
        ),
      };
      return const ReviewActionResult(success: true);
    } catch (e) {
      final latest = stateFor(spotId);
      state = {
        ...state,
        spotId: latest.copyWith(isSubmitting: false),
      };
      return ReviewActionResult(
        success: false,
        errorMessage: SpotReviewErrorMapper.map(e),
      );
    }
  }

  Future<ReviewActionResult> editReview({
    required SpotReviewItem target,
    required String currentUserId,
    required String comment,
    int? rating,
  }) async {
    final validationError = SpotReviewLogic.validateComment(comment);
    if (validationError != null) {
      return ReviewActionResult(success: false, errorMessage: validationError);
    }

    try {
      await ref.read(spotReviewGatewayProvider).updateReview(
            target: target,
            currentUserId: currentUserId,
            comment: comment,
            rating: rating,
          );
      return const ReviewActionResult(success: true);
    } catch (e) {
      return ReviewActionResult(
        success: false,
        errorMessage: SpotReviewErrorMapper.map(e),
      );
    }
  }

  Future<ReviewActionResult> deleteReview({
    required SpotReviewItem target,
    required String currentUserId,
  }) async {
    try {
      await ref.read(spotReviewGatewayProvider).deleteReview(
            target: target,
            currentUserId: currentUserId,
          );
      final current = stateFor(target.spotId);
      if (current.replyingTo?.id == target.id) {
        cancelReply(target.spotId);
      }
      return const ReviewActionResult(success: true);
    } catch (e) {
      return ReviewActionResult(
        success: false,
        errorMessage: SpotReviewErrorMapper.map(e),
      );
    }
  }
}

final spotReviewControllerProvider =
    NotifierProvider<SpotReviewController, ReviewComposerStateMap>(
  SpotReviewController.new,
);