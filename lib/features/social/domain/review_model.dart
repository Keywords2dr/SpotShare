import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    this.photoUrls = const [],
    this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final int rating;
  final String comment;
  final List<String> photoUrls;
  final DateTime? createdAt;

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map ? raw : const {};
    final rawPhotos = data['photoUrls'];
    final photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : const <String>[];

    return ReviewModel(
      id: (data['id'] as String?) ?? doc.id,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      userAvatar: (data['userAvatar'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      comment: (data['comment'] as String?) ?? '',
      photoUrls: photos,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}