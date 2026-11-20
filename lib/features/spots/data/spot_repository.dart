import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/spot_model.dart';

class SpotRepository {
  SpotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  late final _spotsRef = _firestore.collection('spots');
  late final _usersRef = _firestore.collection('users');

  Future<SpotModel> createSpot({
    required String title,
    required String description,
    required String category,
    required List<String> imageUrls,
    required double latitude,
    required double longitude,
    required String addressText,
    required String bestTimeTag,
    required String difficultyTag,
    required String priceTag,
    required String authorId,
    required String authorName,
    required String authorAvatar,
  }) async {
    final docRef = _spotsRef.doc();
    final userSnap = await _usersRef.doc(authorId).get();
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final dbName = (userData['displayName'] as String?)?.trim() ?? '';
    final dbAvatar = (userData['avatarUrl'] as String?)?.trim() ?? '';

    final spot = SpotModel(
      id: docRef.id,
      title: title.trim(),
      description: description.trim(),
      category: category.trim(),
      imageUrls: imageUrls,
      latitude: latitude,
      longitude: longitude,
      addressText: addressText.trim(),
      bestTimeTag: bestTimeTag.trim(),
      difficultyTag: difficultyTag.trim(),
      priceTag: priceTag.trim(),
      authorId: authorId,
      authorName: dbName.isNotEmpty ? dbName : authorName.trim(),
      authorAvatar: dbAvatar.isNotEmpty ? dbAvatar : authorAvatar.trim(),
    );

    await docRef.set(spot.toCreateMap());

    await _usersRef.doc(authorId).set(
      {
        'spotsCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    return spot;
  }

  Future<List<SpotModel>> fetchExploreFeed({
    int limit = 15,
    String? category,
    DocumentSnapshot? startAfterDoc,
  }) async {
    Query query = _spotsRef.orderBy('createdAt', descending: true);

    if (category != null && category.isNotEmpty && category != 'Tất cả') {
      query = query.where('category', isEqualTo: category);
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList();
  }

  Stream<List<SpotModel>> watchRecentSpots({int limit = 50}) {
    return _spotsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<SpotModel?> watchSpotById(String spotId) {
    return _spotsRef.doc(spotId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return SpotModel.fromFirestore(snapshot);
    });
  }

  Stream<List<SpotModel>> watchUserSpots(String userId) {
    return _spotsRef
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final spots =
          snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList();
      spots.sort((a, b) {
        final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      return spots;
    });
  }
}