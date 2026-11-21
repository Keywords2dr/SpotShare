import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../social/presentation/social_providers.dart';
import '../../spots/domain/spot_model.dart';
import '../../spots/presentation/spot_providers.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userProfileProvider =
    StreamProvider.family<UserProfileModel?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).watchUserProfile(userId);
});

final userAvatarProvider =
    StreamProvider.family<String, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).watchUserAvatar(userId);
});

final userSearchProvider =
    FutureProvider.family<List<UserProfileModel>, String>((ref, query) {
  return ref.watch(profileRepositoryProvider).searchUsers(query);
});

final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) {
    return Stream.value(false);
  }
  return ref.watch(profileRepositoryProvider).watchIsFollowing(
        currentUserId: authUser.uid,
        targetUserId: targetUserId,
      );
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