import 'package:cloud_firestore/cloud_firestore.dart';

class SpotModel {
  const SpotModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.addressText,
    required this.bestTimeTag,
    required this.difficultyTag,
    required this.priceTag,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.likesCount = 0,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String addressText;
  final String bestTimeTag;
  final String difficultyTag;
  final String priceTag;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final int likesCount;
  final double ratingAvg;
  final int ratingCount;
  final DateTime? createdAt;

  factory SpotModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map ? raw : const {};
    final rawImages = data['imageUrls'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : const <String>[];

    return SpotModel(
      id: (data['id'] as String?) ?? doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      imageUrls: images,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      addressText: (data['addressText'] as String?) ?? '',
      bestTimeTag: (data['bestTimeTag'] as String?) ?? '',
      difficultyTag: (data['difficultyTag'] as String?) ?? '',
      priceTag: (data['priceTag'] as String?) ?? '',
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatar: (data['authorAvatar'] as String?) ?? '',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'latitude': latitude,
      'longitude': longitude,
      'addressText': addressText,
      'bestTimeTag': bestTimeTag,
      'difficultyTag': difficultyTag,
      'priceTag': priceTag,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'likesCount': likesCount,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}