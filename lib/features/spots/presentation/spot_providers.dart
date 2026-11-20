import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/cloudinary_service.dart';
import '../data/spot_repository.dart';
import '../domain/spot_model.dart';

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

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  return SpotRepository();
});

final exploreSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(spotRepositoryProvider).watchRecentSpots(limit: 20);
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