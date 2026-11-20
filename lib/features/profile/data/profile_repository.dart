import 'package:cloud_firestore/cloud_firestore.dart';

typedef JsonMap = Map<String, dynamic>;

class _BatchUpdate {
  const _BatchUpdate(this.reference, this.data);

  final DocumentReference reference;
  final JsonMap data;
}

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  late final _usersRef = _firestore.collection('users');
  late final _spotsRef = _firestore.collection('spots');

  Stream<JsonMap> watchUserData(String userId) {
    return _usersRef
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() ?? const <String, dynamic>{});
  }

  Stream<String> watchUserAvatar(String userId) {
    if (userId.isEmpty) {
      return Stream.value('');
    }
    return _usersRef.doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return (data?['avatarUrl'] as String?)?.trim() ?? '';
    });
  }

  Future<void> updateUserBio({
    required String userId,
    required String bio,
  }) async {
    await _usersRef.doc(userId).set(
      {
        'bio': bio.trim(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    final trimmedUrl = avatarUrl.trim();
    await _usersRef.doc(userId).set(
      {
        'avatarUrl': trimmedUrl,
      },
      SetOptions(merge: true),
    );

    final updates = <_BatchUpdate>[];

    final userSpotsSnap =
        await _spotsRef.where('authorId', isEqualTo: userId).get();
    for (final doc in userSpotsSnap.docs) {
      updates.add(_BatchUpdate(doc.reference, {'authorAvatar': trimmedUrl}));
    }

    try {
      final userReviewsSnap = await _firestore
          .collectionGroup('reviews')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in userReviewsSnap.docs) {
        updates.add(_BatchUpdate(doc.reference, {'userAvatar': trimmedUrl}));
      }
    } catch (_) {
      final allSpotsSnap = await _spotsRef.get();
      for (final spotDoc in allSpotsSnap.docs) {
        final reviewsSnap = await spotDoc.reference
            .collection('reviews')
            .where('userId', isEqualTo: userId)
            .get();
        for (final reviewDoc in reviewsSnap.docs) {
          updates.add(
            _BatchUpdate(reviewDoc.reference, {'userAvatar': trimmedUrl}),
          );
        }
      }
    }

    const batchLimit = 400;
    for (int i = 0; i < updates.length; i += batchLimit) {
      final end =
          (i + batchLimit < updates.length) ? i + batchLimit : updates.length;
      final batch = _firestore.batch();
      for (int j = i; j < end; j++) {
        batch.update(updates[j].reference, updates[j].data);
      }
      await batch.commit();
    }
  }
}