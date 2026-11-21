import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile_model.dart';

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
  late final _usernamesRef = _firestore.collection('usernames');
  late final _spotsRef = _firestore.collection('spots');

  Stream<JsonMap> watchUserData(String userId) {
    return _usersRef
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() ?? const <String, dynamic>{});
  }

  Stream<UserProfileModel?> watchUserProfile(String userId) {
    if (userId.isEmpty) {
      return Stream.value(null);
    }
    return _usersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfileModel.fromFirestore(doc);
    });
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

  Future<void> ensureDefaultUsername({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    final userSnap = await _usersRef.doc(userId).get();
    final data = userSnap.data() ?? const <String, dynamic>{};
    final existing = (data['username'] as String?)?.trim().toLowerCase() ?? '';
    if (existing.isNotEmpty) {
      final handleDoc = await _usernamesRef.doc(existing).get();
      if (!handleDoc.exists) {
        await _usernamesRef.doc(existing).set({
          'uid': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    final rawBase = email.isNotEmpty ? email.split('@').first : displayName;
    var candidate = UserProfileModel.normalizeUsername(rawBase);
    if (candidate.length < 3) {
      final suffix = userId
          .substring(0, userId.length >= 6 ? 6 : userId.length)
          .toLowerCase();
      candidate = 'user$suffix';
    }
    if (candidate.length > 16) {
      candidate = candidate.substring(0, 16);
    }

    try {
      await updateUsername(userId: userId, rawUsername: candidate);
    } catch (_) {
      final suffix = userId
          .substring(0, userId.length >= 4 ? 4 : userId.length)
          .toLowerCase();
      final fallback = '${candidate}_$suffix';
      try {
        await updateUsername(userId: userId, rawUsername: fallback);
      } catch (_) {}
    }
  }

  Future<String> updateUsername({
    required String userId,
    required String rawUsername,
  }) async {
    final normalized = UserProfileModel.normalizeUsername(rawUsername);
    if (!UserProfileModel.isValidUsername(normalized)) {
      throw Exception(
        'SpotShare ID chỉ gồm chữ thường không dấu, số, dấu "." hoặc "_" (3–20 ký tự).',
      );
    }

    final userRef = _usersRef.doc(userId);
    final newHandleRef = _usernamesRef.doc(normalized);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final newHandleSnap = await transaction.get(newHandleRef);

      final userData = userSnap.data() ?? const <String, dynamic>{};
      final oldUsername =
          (userData['username'] as String?)?.trim().toLowerCase() ?? '';

      DocumentSnapshot? oldHandleSnap;
      if (oldUsername.isNotEmpty && oldUsername != normalized) {
        oldHandleSnap = await transaction.get(_usernamesRef.doc(oldUsername));
      }

      if (newHandleSnap.exists) {
        final ownerId = (newHandleSnap.data()?['uid'] as String?) ?? '';
        if (ownerId.isNotEmpty && ownerId != userId) {
          throw Exception('SpotShare ID @$normalized đã có người sử dụng.');
        }
      }

      if (oldHandleSnap != null && oldHandleSnap.exists) {
        final rawOldData = oldHandleSnap.data();
        final oldOwnerId =
            rawOldData is Map ? (rawOldData['uid'] as String?) ?? '' : '';
        if (oldOwnerId == userId) {
          transaction.delete(oldHandleSnap.reference);
        }
      }

      transaction.set(newHandleRef, {
        'uid': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        userRef,
        {'username': normalized},
        SetOptions(merge: true),
      );
    });

    return normalized;
  }

  Future<void> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.length < 2 || trimmed.length > 40) {
      throw Exception('Tên hiển thị phải từ 2 đến 40 ký tự.');
    }

    await _usersRef.doc(userId).set(
      {
        'displayName': trimmed,
      },
      SetOptions(merge: true),
    );

    await _syncAuthorMetadata(
      userId: userId,
      spotField: 'authorName',
      reviewField: 'userName',
      value: trimmed,
    );
  }

  Future<List<UserProfileModel>> searchUsers(String rawQuery) async {
    final trimmed = rawQuery.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final handleQuery = UserProfileModel.normalizeUsername(trimmed);
    final foundById = <String, UserProfileModel>{};

    if (handleQuery.isNotEmpty) {
      final prefixSnap = await _usersRef
          .where('username', isGreaterThanOrEqualTo: handleQuery)
          .where('username', isLessThanOrEqualTo: '$handleQuery\uf8ff')
          .limit(15)
          .get();

      for (final doc in prefixSnap.docs) {
        foundById[doc.id] = UserProfileModel.fromFirestore(doc);
      }
    }

    final fallbackSnap = await _usersRef.limit(60).get();
    final isHandleOnly = trimmed.startsWith('@');
    for (final doc in fallbackSnap.docs) {
      if (foundById.containsKey(doc.id)) continue;
      final profile = UserProfileModel.fromFirestore(doc);
      final usernameLower = profile.username.toLowerCase();
      final nameLower = profile.displayName.toLowerCase();

      final matchesHandle =
          handleQuery.isNotEmpty && usernameLower.contains(handleQuery);
      final matchesName = !isHandleOnly && nameLower.contains(trimmed);

      if (matchesHandle || matchesName) {
        foundById[doc.id] = profile;
      }
    }

    final results = foundById.values.toList();
    results.sort((a, b) {
      final aExact = a.username == handleQuery ? 0 : 1;
      final bExact = b.username == handleQuery ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      final aStarts = a.username.startsWith(handleQuery) ? 0 : 1;
      final bStarts = b.username.startsWith(handleQuery) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      return a.displayName.compareTo(b.displayName);
    });
    return results.take(15).toList();
  }

  Stream<bool> watchIsFollowing({
    required String currentUserId,
    required String targetUserId,
  }) {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return Stream.value(false);
    }
    return _usersRef
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return false;

    final currentUserRef = _usersRef.doc(currentUserId);
    final targetUserRef = _usersRef.doc(targetUserId);
    final followingRef =
        currentUserRef.collection('following').doc(targetUserId);
    final followerRef = targetUserRef.collection('followers').doc(currentUserId);

    return _firestore.runTransaction((transaction) async {
      final followingSnap = await transaction.get(followingRef);
      final currentUserSnap = await transaction.get(currentUserRef);
      final targetUserSnap = await transaction.get(targetUserRef);

      final currentFollowing =
          (currentUserSnap.data()?['followingCount'] as num?)?.toInt() ?? 0;
      final targetFollowers =
          (targetUserSnap.data()?['followersCount'] as num?)?.toInt() ?? 0;

      if (followingSnap.exists) {
        transaction.delete(followingRef);
        transaction.delete(followerRef);
        transaction.set(
          currentUserRef,
          {'followingCount': currentFollowing > 0 ? currentFollowing - 1 : 0},
          SetOptions(merge: true),
        );
        transaction.set(
          targetUserRef,
          {'followersCount': targetFollowers > 0 ? targetFollowers - 1 : 0},
          SetOptions(merge: true),
        );
        return false;
      } else {
        transaction.set(followingRef, {
          'uid': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(followerRef, {
          'uid': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          currentUserRef,
          {'followingCount': currentFollowing + 1},
          SetOptions(merge: true),
        );
        transaction.set(
          targetUserRef,
          {'followersCount': targetFollowers + 1},
          SetOptions(merge: true),
        );
        return true;
      }
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

    await _syncAuthorMetadata(
      userId: userId,
      spotField: 'authorAvatar',
      reviewField: 'userAvatar',
      value: trimmedUrl,
    );
  }

  Future<void> _syncAuthorMetadata({
    required String userId,
    required String spotField,
    required String reviewField,
    required String value,
  }) async {
    final updates = <_BatchUpdate>[];

    final userSpotsSnap =
        await _spotsRef.where('authorId', isEqualTo: userId).get();
    for (final doc in userSpotsSnap.docs) {
      updates.add(_BatchUpdate(doc.reference, {spotField: value}));
    }

    try {
      final userReviewsSnap = await _firestore
          .collectionGroup('reviews')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in userReviewsSnap.docs) {
        updates.add(_BatchUpdate(doc.reference, {reviewField: value}));
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
            _BatchUpdate(reviewDoc.reference, {reviewField: value}),
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