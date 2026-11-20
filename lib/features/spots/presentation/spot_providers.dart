import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/cloudinary_service.dart';
import '../data/place_search_service.dart';
import '../data/spot_repository.dart';
import '../domain/review_model.dart';
import '../domain/spot_model.dart';

enum ExploreSortMode {
  trending,
  newest,
}

class ExploreSortModeNotifier extends Notifier<ExploreSortMode> {
  @override
  ExploreSortMode build() => ExploreSortMode.trending;

  void setMode(ExploreSortMode mode) {
    state = mode;
  }
}

final exploreSortModeProvider =
    NotifierProvider<ExploreSortModeNotifier, ExploreSortMode>(
  ExploreSortModeNotifier.new,
);

double calculateSpotTrendingScore(SpotModel spot, DateTime now) {
  final engagement = (spot.likesCount * 2.0) +
      (spot.ratingCount * 3.0) +
      (spot.ratingAvg * spot.ratingCount * 0.5) +
      1.0;
  final createdAt = spot.createdAt ?? now;
  final ageInHours = math.max(0.0, now.difference(createdAt).inMinutes / 60.0);
  final gravity = math.pow(ageInHours + 2.0, 1.2).toDouble();
  return engagement / gravity;
}

class CreateSpotUploadState {
  const CreateSpotUploadState({
    this.isSubmitting = false,
    this.currentIndex = 0,
    this.totalCount = 0,
    this.fileProgress = 0.0,
    this.statusMessage = '',
  });

  final bool isSubmitting;
  final int currentIndex;
  final int totalCount;
  final double fileProgress;
  final String statusMessage;

  double get overallProgress {
    if (totalCount <= 0) return 0.0;
    final completed = currentIndex.toDouble();
    return ((completed + fileProgress) / totalCount).clamp(0.0, 1.0);
  }

  CreateSpotUploadState copyWith({
    bool? isSubmitting,
    int? currentIndex,
    int? totalCount,
    double? fileProgress,
    String? statusMessage,
  }) {
    return CreateSpotUploadState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      currentIndex: currentIndex ?? this.currentIndex,
      totalCount: totalCount ?? this.totalCount,
      fileProgress: fileProgress ?? this.fileProgress,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  return PlaceSearchService();
});

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  return SpotRepository();
});

final exploreSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(spotRepositoryProvider).watchRecentSpots(limit: 50);
});

final rankedExploreSpotsProvider = Provider<AsyncValue<List<SpotModel>>>((ref) {
  final spotsAsync = ref.watch(exploreSpotsProvider);
  final sortMode = ref.watch(exploreSortModeProvider);

  return spotsAsync.whenData((spots) {
    final sorted = List<SpotModel>.from(spots);
    if (sortMode == ExploreSortMode.trending) {
      final now = DateTime.now();
      sorted.sort((a, b) {
        final scoreB = calculateSpotTrendingScore(b, now);
        final scoreA = calculateSpotTrendingScore(a, now);
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) return scoreCompare;
        final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
    } else {
      sorted.sort((a, b) {
        final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
    }
    return sorted;
  });
});

final spotDetailProvider = StreamProvider.family<SpotModel?, String>((
  ref,
  spotId,
) {
  return ref.watch(spotRepositoryProvider).watchSpotById(spotId);
});

final spotLikedProvider = StreamProvider.family<bool, String>((ref, spotId) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) {
    return Stream.value(false);
  }
  return ref
      .watch(spotRepositoryProvider)
      .watchIsSpotLiked(spotId, authUser.uid);
});

final spotReviewsProvider =
    StreamProvider.family<List<ReviewModel>, String>((ref, spotId) {
  return ref.watch(spotRepositoryProvider).watchReviews(spotId);
});

class CreateSpotController extends AsyncNotifier<CreateSpotUploadState> {
  @override
  FutureOr<CreateSpotUploadState> build() {
    return const CreateSpotUploadState();
  }

  void resetState() {
    state = const AsyncData(CreateSpotUploadState());
  }

  Future<bool> publishSpot({
    required String title,
    required String description,
    required String category,
    required List<XFile> pickedImages,
    required double latitude,
    required double longitude,
    required String addressText,
    required String bestTimeTag,
    required String difficultyTag,
    required String priceTag,
  }) async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      state = AsyncError(
        Exception('Vui lòng đăng nhập trước khi đăng địa điểm.'),
        StackTrace.current,
      );
      return false;
    }

    if (pickedImages.isEmpty) {
      state = AsyncError(
        Exception('Vui lòng chọn ít nhất 1 ảnh cho địa điểm.'),
        StackTrace.current,
      );
      return false;
    }

    if (pickedImages.length > 6) {
      state = AsyncError(
        Exception('Chỉ được tải lên tối đa 6 ảnh cho mỗi địa điểm.'),
        StackTrace.current,
      );
      return false;
    }

    state = AsyncData(
      CreateSpotUploadState(
        isSubmitting: true,
        currentIndex: 0,
        totalCount: pickedImages.length,
        fileProgress: 0.0,
        statusMessage: 'Đang nén & tải ảnh lên Cloudinary...',
      ),
    );

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final imageUrls = await cloudinary.uploadImages(
        pickedImages,
        onFileProgress: (index, total, progress) {
          state = AsyncData(
            CreateSpotUploadState(
              isSubmitting: true,
              currentIndex: index,
              totalCount: total,
              fileProgress: progress,
              statusMessage:
                  'Đang tải ảnh ${index + 1}/$total (${(progress * 100).round()}%)...',
            ),
          );
        },
      );

      state = AsyncData(
        CreateSpotUploadState(
          isSubmitting: true,
          currentIndex: pickedImages.length,
          totalCount: pickedImages.length,
          fileProgress: 1.0,
          statusMessage: 'Đang lưu địa điểm lên Firestore...',
        ),
      );

      final profile = ref.read(currentUserProfileProvider).value;
      final resolvedName = (profile?.displayName.isNotEmpty == true)
          ? profile!.displayName
          : ((authUser.displayName ?? '').trim().isNotEmpty
              ? authUser.displayName!.trim()
              : (authUser.email ?? 'Thành viên SpotShare').split('@').first);
      final resolvedAvatar = (profile?.avatarUrl.isNotEmpty == true)
          ? profile!.avatarUrl
          : (authUser.photoURL ?? '');

      await ref.read(spotRepositoryProvider).createSpot(
            title: title,
            description: description,
            category: category,
            imageUrls: imageUrls,
            latitude: latitude,
            longitude: longitude,
            addressText: addressText,
            bestTimeTag: bestTimeTag,
            difficultyTag: difficultyTag,
            priceTag: priceTag,
            authorId: authUser.uid,
            authorName: resolvedName,
            authorAvatar: resolvedAvatar,
          );

      state = const AsyncData(CreateSpotUploadState());
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final createSpotControllerProvider =
    AsyncNotifierProvider<CreateSpotController, CreateSpotUploadState>(
  CreateSpotController.new,
);