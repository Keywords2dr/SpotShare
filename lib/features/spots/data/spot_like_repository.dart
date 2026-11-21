import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef FirestoreDoc = Map<String, dynamic>;

class SpotLikeException implements Exception {
  const SpotLikeException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class SpotLikeResult {
  const SpotLikeResult({
    required this.isLiked,
    required this.likesCount,
    this.reachedMilestone,
  });

  final bool isLiked;
  final int likesCount;
  final int? reachedMilestone;
}

class SpotLikeLogic {
  static const List<int> milestones = [10, 50, 100];

  static int parseNonNegativeInt(Object? raw) {
    if (raw is int) {
      return raw < 0 ? 0 : raw;
    }
    if (raw is num) {
      final value = raw.toInt();
      return value < 0 ? 0 : value;
    }
    return 0;
  }

  static int computeNextCount({
    required int currentCount,
    required bool willLike,
  }) {
    final safeCurrent = currentCount < 0 ? 0 : currentCount;
    if (willLike) {
      return safeCurrent + 1;
    }
    return safeCurrent > 0 ? safeCurrent - 1 : 0;
  }

  static int? detectReachedMilestone({
    required int previousCount,
    required int nextCount,
    required bool willLike,
  }) {
    if (!willLike || nextCount <= previousCount) {
      return null;
    }
    if (milestones.contains(nextCount)) {
      return nextCount;
    }
    return null;
  }
}

abstract class SpotLikeGateway {
  Stream<bool> watchIsLiked({
    required String spotId,
    required String userId,
  });

  Future<SpotLikeResult> toggleLike({
    required String spotId,
    required String userId,
    String? authorId,
  });
}

class FirestoreSpotLikeRepository implements SpotLikeGateway {
  FirestoreSpotLikeRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Stream<bool> watchIsLiked({
    required String spotId,
    required String userId,
  }) {
    final cleanSpotId = spotId.trim();
    final cleanUserId = userId.trim();
    if (cleanSpotId.isEmpty || cleanUserId.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _db
        .collection('spots')
        .doc(cleanSpotId)
        .collection('likes')
        .doc(cleanUserId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Future<SpotLikeResult> toggleLike({
    required String spotId,
    required String userId,
    String? authorId,
  }) async {
    final cleanSpotId = spotId.trim();
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw const SpotLikeException(
        'Vui lòng đăng nhập để thả tim địa điểm.',
        code: 'unauthenticated',
      );
    }
    if (cleanSpotId.isEmpty) {
      throw const SpotLikeException(
        'Không tìm thấy địa điểm cần thao tác.',
        code: 'invalid-argument',
      );
    }

    final spotRef = _db.collection('spots').doc(cleanSpotId);
    final likeRef = spotRef.collection('likes').doc(cleanUserId);
    final userLikedRef = _db
        .collection('users')
        .doc(cleanUserId)
        .collection('likedSpots')
        .doc(cleanSpotId);

    String resolvedAuthorId = (authorId ?? '').trim();

    try {
      final result = await _db.runTransaction<SpotLikeResult>(
        (transaction) async {
          final spotSnap = await transaction.get(spotRef);
          if (!spotSnap.exists) {
            throw const SpotLikeException(
              'Bài đăng này không còn tồn tại.',
              code: 'not-found',
            );
          }

          final FirestoreDoc spotData = spotSnap.data() ?? {};
          final likeSnap = await transaction.get(likeRef);

          final docAuthorId = (spotData['authorId'] as String?)?.trim() ?? '';
          if (docAuthorId.isNotEmpty) {
            resolvedAuthorId = docAuthorId;
          }

          final willLike = !likeSnap.exists;
          final currentLikes =
              SpotLikeLogic.parseNonNegativeInt(spotData['likesCount']);
          final nextLikes = SpotLikeLogic.computeNextCount(
            currentCount: currentLikes,
            willLike: willLike,
          );
          final reachedMilestone = SpotLikeLogic.detectReachedMilestone(
            previousCount: currentLikes,
            nextCount: nextLikes,
            willLike: willLike,
          );

          if (willLike) {
            transaction.set(likeRef, {
              'userId': cleanUserId,
              'spotId': cleanSpotId,
              'createdAt': FieldValue.serverTimestamp(),
            });
            transaction.set(userLikedRef, {
              'spotId': cleanSpotId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            transaction.delete(likeRef);
            transaction.delete(userLikedRef);
          }

          transaction.update(spotRef, {
            'likesCount': nextLikes,
          });

          return SpotLikeResult(
            isLiked: willLike,
            likesCount: nextLikes,
            reachedMilestone: reachedMilestone,
          );
        },
      );

      if (resolvedAuthorId.isNotEmpty) {
        await _syncAuthorTotalLikes(
          authorId: resolvedAuthorId,
          willLike: result.isLiked,
        );
      }

      return result;
    } on SpotLikeException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotLikeRepository] toggleLike failed (${e.code}): ${e.message}',
        );
      }
      throw SpotLikeException(mapErrorCode(e.code), code: e.code);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotLikeRepository] toggleLike unexpected error: $e');
      }
      throw const SpotLikeException(
        'Không thể cập nhật lượt thích lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  Future<void> _syncAuthorTotalLikes({
    required String authorId,
    required bool willLike,
  }) async {
    try {
      final authorRef = _db.collection('users').doc(authorId);
      await _db.runTransaction<void>((transaction) async {
        final authorSnap = await transaction.get(authorRef);
        if (!authorSnap.exists) return;

        final FirestoreDoc authorData = authorSnap.data() ?? {};
        final currentTotalLikes =
            SpotLikeLogic.parseNonNegativeInt(authorData['totalLikes']);
        final nextTotalLikes = SpotLikeLogic.computeNextCount(
          currentCount: currentTotalLikes,
          willLike: willLike,
        );
        transaction.update(authorRef, {
          'totalLikes': nextTotalLikes,
        });
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotLikeRepository] non-fatal totalLikes sync skipped: $e',
        );
      }
    }
  }

  static String mapErrorCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Bạn chưa được cấp quyền cập nhật lượt thích. Vui lòng kiểm tra phiên đăng nhập hoặc Firestore Rules.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'not-found':
        return 'Địa điểm này đã bị xóa hoặc không còn tồn tại.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
      case 'aborted':
      case 'deadline-exceeded':
        return 'Hệ thống đang bận xử lý lượt thích. Vui lòng thử lại sau giây lát.';
      default:
        return 'Không thể cập nhật lượt thích lúc này. Vui lòng thử lại.';
    }
  }
}