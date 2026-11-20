import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/review_model.dart';

class ReviewRepository {
  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  late final _spotsRef = _firestore.collection('spots');
  late final _usersRef = _firestore.collection('users');

  Stream<List<ReviewModel>> watchReviews(String spotId) {
    return _spotsRef
        .doc(spotId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList(),
        );
  }

  Future<void> addReview({
    required String spotId,
    required String userId,
    required String userName,
    required String userAvatar,
    required int rating,
    required String comment,
    List<String> photoUrls = const [],
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw Exception('Vui lòng nhập nội dung bình luận.');
    }

    final spotRef = _spotsRef.doc(spotId);
    final userRef = _usersRef.doc(userId);
    final reviewRef = spotRef.collection('reviews').doc();

    await _firestore.runTransaction((transaction) async {
      final spotSnap = await transaction.get(spotRef);
      if (!spotSnap.exists) {
        throw Exception('Địa điểm không tồn tại.');
      }

      final userSnap = await transaction.get(userRef);
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final dbName = (userData['displayName'] as String?)?.trim() ?? '';
      final dbAvatar = (userData['avatarUrl'] as String?)?.trim() ?? '';

      final review = ReviewModel(
        id: reviewRef.id,
        userId: userId,
        userName: dbName.isNotEmpty ? dbName : userName.trim(),
        userAvatar: dbAvatar.isNotEmpty ? dbAvatar : userAvatar.trim(),
        rating: rating.clamp(1, 5),
        comment: trimmedComment,
        photoUrls: photoUrls,
      );

      final spotData = spotSnap.data() ?? const <String, dynamic>{};
      final oldCount = (spotData['ratingCount'] as num?)?.toInt() ?? 0;
      final oldAvg = (spotData['ratingAvg'] as num?)?.toDouble() ?? 0.0;

      final newCount = oldCount + 1;
      final newAvg = ((oldAvg * oldCount) + review.rating) / newCount;

      transaction.set(reviewRef, review.toCreateMap());
      transaction.update(spotRef, {
        'ratingCount': newCount,
        'ratingAvg': double.parse(newAvg.toStringAsFixed(2)),
      });
    });
  }

  Future<void> deleteReview({
    required String spotId,
    required String reviewId,
    required String userId,
  }) async {
    final spotRef = _spotsRef.doc(spotId);
    final reviewRef = spotRef.collection('reviews').doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final spotSnap = await transaction.get(spotRef);
      if (!spotSnap.exists) {
        throw Exception('Địa điểm không tồn tại.');
      }

      final reviewSnap = await transaction.get(reviewRef);
      if (!reviewSnap.exists) {
        throw Exception('Bình luận không tồn tại hoặc đã bị xóa.');
      }

      final reviewData = reviewSnap.data() ?? const <String, dynamic>{};
      final reviewOwnerId = (reviewData['userId'] as String?) ?? '';
      if (reviewOwnerId != userId) {
        throw Exception('Bạn chỉ có thể xóa bình luận của chính mình.');
      }

      final removedRating = (reviewData['rating'] as num?)?.toInt() ?? 0;
      final spotData = spotSnap.data() ?? const <String, dynamic>{};
      final oldCount = (spotData['ratingCount'] as num?)?.toInt() ?? 0;
      final oldAvg = (spotData['ratingAvg'] as num?)?.toDouble() ?? 0.0;

      final newCount = oldCount > 1 ? oldCount - 1 : 0;
      final newAvg = newCount == 0
          ? 0.0
          : (((oldAvg * oldCount) - removedRating) / newCount).clamp(0.0, 5.0);

      transaction.delete(reviewRef);
      transaction.update(spotRef, {
        'ratingCount': newCount,
        'ratingAvg': double.parse(newAvg.toStringAsFixed(2)),
      });
    });
  }
}