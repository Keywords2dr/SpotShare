import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/interaction_repository.dart';
import '../data/review_repository.dart';
import '../domain/review_model.dart';

final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepository();
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

final spotLikedProvider = StreamProvider.family<bool, String>((ref, spotId) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) {
    return Stream.value(false);
  }
  return ref
      .watch(interactionRepositoryProvider)
      .watchIsSpotLiked(spotId, authUser.uid);
});

final spotSavedProvider = StreamProvider.family<bool, String>((ref, spotId) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) {
    return Stream.value(false);
  }
  return ref
      .watch(interactionRepositoryProvider)
      .watchIsSpotSaved(spotId, authUser.uid);
});

final spotReviewsProvider =
    StreamProvider.family<List<ReviewModel>, String>((ref, spotId) {
  return ref.watch(reviewRepositoryProvider).watchReviews(spotId);
});