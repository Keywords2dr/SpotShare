import 'package:cloud_firestore/cloud_firestore.dart';

import '../../spots/domain/spot_model.dart';

class InteractionRepository {
  InteractionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  late final _spotsRef = _firestore.collection('spots');
  late final _usersRef = _firestore.collection('users');

  Future<List<SpotModel>> _fetchSpotsByIds(List<String> spotIds) async {
    if (spotIds.isEmpty) return const [];
    final results = <SpotModel>[];
    for (final id in spotIds) {
      final doc = await _spotsRef.doc(id).get();
      if (doc.exists) {
        results.add(SpotModel.fromFirestore(doc));
      }
    }
    return results;
  }

  Stream<bool> watchIsSpotLiked(String spotId, String userId) {
    return _spotsRef
        .doc(spotId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> toggleLike({
    required String spotId,
    required String userId,
    required String authorId,
  }) async {
    final spotRef = _spotsRef.doc(spotId);
    final likeRef = spotRef.collection('likes').doc(userId);
    final userLikedRef =
        _usersRef.doc(userId).collection('liked_spots').doc(spotId);
    final authorRef = _usersRef.doc(authorId);

    return _firestore.runTransaction((transaction) async {
      final spotSnap = await transaction.get(spotRef);
      if (!spotSnap.exists) {
        throw Exception('Địa điểm không tồn tại.');
      }

      final likeSnap = await transaction.get(likeRef);
      final spotData = spotSnap.data() ?? const <String, dynamic>{};
      final currentLikes = (spotData['likesCount'] as num?)?.toInt() ?? 0;

      if (likeSnap.exists) {
        transaction.delete(likeRef);
        transaction.delete(userLikedRef);
        transaction.update(spotRef, {
          'likesCount': currentLikes > 0 ? currentLikes - 1 : 0,
        });
        if (authorId.isNotEmpty) {
          transaction.set(
            authorRef,
            {'totalLikes': FieldValue.increment(-1)},
            SetOptions(merge: true),
          );
        }
        return false;
      } else {
        transaction.set(likeRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userLikedRef, {
          'spotId': spotId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(spotRef, {
          'likesCount': currentLikes + 1,
        });
        if (authorId.isNotEmpty) {
          transaction.set(
            authorRef,
            {'totalLikes': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
        return true;
      }
    });
  }

  Stream<List<SpotModel>> watchLikedSpots(String userId) {
    return _usersRef
        .doc(userId)
        .collection('liked_spots')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchSpotsByIds(ids);
    });
  }

  Stream<bool> watchIsSpotSaved(String spotId, String userId) {
    return _usersRef
        .doc(userId)
        .collection('collections')
        .doc('saved')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() ?? const <String, dynamic>{};
      final rawIds = data['spotIds'];
      if (rawIds is! List) return false;
      return rawIds.map((e) => e.toString()).contains(spotId);
    });
  }

  Future<bool> toggleSaveSpot({
    required String spotId,
    required String userId,
  }) async {
    final savedRef =
        _usersRef.doc(userId).collection('collections').doc('saved');

    return _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(savedRef);
      final data = snap.data() ?? const <String, dynamic>{};
      final rawIds = data['spotIds'];
      final currentIds = rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : <String>[];

      if (currentIds.contains(spotId)) {
        currentIds.remove(spotId);
        transaction.set(
          savedRef,
          {
            'id': 'saved',
            'name': 'Đã lưu',
            'spotIds': currentIds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return false;
      } else {
        currentIds.insert(0, spotId);
        transaction.set(
          savedRef,
          {
            'id': 'saved',
            'name': 'Đã lưu',
            'spotIds': currentIds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return true;
      }
    });
  }

  Stream<List<SpotModel>> watchSavedSpots(String userId) {
    return _usersRef
        .doc(userId)
        .collection('collections')
        .doc('saved')
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return const <SpotModel>[];
      final data = doc.data() ?? const <String, dynamic>{};
      final rawIds = data['spotIds'];
      if (rawIds is! List) return const <SpotModel>[];
      final ids = rawIds.map((e) => e.toString()).toList();
      return _fetchSpotsByIds(ids);
    });
  }
}