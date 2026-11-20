import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../social/presentation/social_providers.dart';
import '../../spots/domain/spot_model.dart';
import '../../spots/presentation/spot_providers.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userAvatarProvider =
    StreamProvider.family<String, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).watchUserAvatar(userId);
});

final userSpotsProvider =
    StreamProvider.family<List<SpotModel>, String>((ref, userId) {
  return ref.watch(spotRepositoryProvider).watchUserSpots(userId);
});

final savedSpotsProvider =
    StreamProvider.family<List<SpotModel>, String>((ref, userId) {
  return ref.watch(interactionRepositoryProvider).watchSavedSpots(userId);
});

final likedSpotsProvider =
    StreamProvider.family<List<SpotModel>, String>((ref, userId) {
  return ref.watch(interactionRepositoryProvider).watchLikedSpots(userId);
});