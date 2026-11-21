import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef FirestoreMap = Map<String, dynamic>;
typedef SpotIdChunk = List<String>;

class LikedSpotsException implements Exception {
  const LikedSpotsException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class LikedSpotRefRecord {
  const LikedSpotRefRecord({
    required this.spotId,
    this.likedAt,
    this.sourceCollection = 'likedSpots',
  });

  final String spotId;
  final DateTime? likedAt;
  final String sourceCollection;
}

class LikedSpotItem {
  const LikedSpotItem({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnailUrl,
    required this.authorId,
    required this.authorName,
    required this.likesCount,
    required this.ratingAvg,
    required this.ratingCount,
    this.addressText = '',
    this.priceTag = '',
    this.likedAt,
  });

  final String id;
  final String title;
  final String category;
  final String thumbnailUrl;
  final String authorId;
  final String authorName;
  final int likesCount;
  final double ratingAvg;
  final int ratingCount;
  final String addressText;
  final String priceTag;
  final DateTime? likedAt;

  factory LikedSpotItem.fromFirestore(
    String id,
    FirestoreMap data, {
    DateTime? likedAt,
  }) {
    final rawImages = data['imageUrls'];
    String thumb = '';
    if (rawImages is List) {
      for (final entry in rawImages) {
        if (entry is String && entry.trim().isNotEmpty) {
          thumb = entry.trim();
          break;
        }
      }
    }

    final rawLikes = data['likesCount'];
    final likes = rawLikes is num ? rawLikes.toInt() : 0;
    final rawRatingAvg = data['ratingAvg'];
    final ratingAvg = rawRatingAvg is num ? rawRatingAvg.toDouble() : 0.0;
    final rawRatingCount = data['ratingCount'];
    final ratingCount = rawRatingCount is num ? rawRatingCount.toInt() : 0;

    return LikedSpotItem(
      id: id,
      title: ((data['title'] as String?) ?? '').trim().isNotEmpty
          ? (data['title'] as String).trim()
          : 'Địa điểm chưa đặt tên',
      category: ((data['category'] as String?) ?? '').trim(),
      thumbnailUrl: thumb,
      authorId: ((data['authorId'] as String?) ?? '').trim(),
      authorName: ((data['authorName'] as String?) ?? '').trim(),
      likesCount: likes < 0 ? 0 : likes,
      ratingAvg: ratingAvg < 0 ? 0 : ratingAvg,
      ratingCount: ratingCount < 0 ? 0 : ratingCount,
      addressText: ((data['addressText'] as String?) ?? '').trim(),
      priceTag: ((data['priceTag'] as String?) ?? '').trim(),
      likedAt: likedAt,
    );
  }
}

class LikedSpotsErrorMapper {
  static String map(
    Object error, {
    String fallback =
        'Không thể tải danh sách địa điểm yêu thích. Vui lòng thử lại.',
  }) {
    if (error is LikedSpotsException) {
      return error.message;
    }

    String? code;
    if (error is FirebaseException) {
      code = error.code;
    }

    final raw = error.toString().toLowerCase();
    final resolvedCode = code ?? _extractCode(raw);

    switch (resolvedCode) {
      case 'permission-denied':
        return 'Bạn chưa có quyền xem danh sách yêu thích. Vui lòng kiểm tra phiên đăng nhập hoặc quy tắc bảo mật Firestore.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Mất kết nối mạng hoặc máy chủ phản hồi chậm. Vui lòng thử lại.';
      case 'failed-precondition':
        return 'Dữ liệu yêu thích đang chờ đồng bộ chỉ mục Firestore. Vui lòng thử lại sau.';
      default:
        return fallback;
    }
  }

  static String? _extractCode(String raw) {
    if (raw.contains('permission-denied')) return 'permission-denied';
    if (raw.contains('unauthenticated')) return 'unauthenticated';
    if (raw.contains('unavailable') || raw.contains('network-request-failed')) {
      return 'unavailable';
    }
    if (raw.contains('deadline-exceeded')) return 'deadline-exceeded';
    if (raw.contains('failed-precondition')) return 'failed-precondition';
    return null;
  }
}

class LikedSpotsLogic {
  static const int maxWhereInChunkSize = 10;

  static List<SpotIdChunk> chunkSpotIds(
    List<String> rawIds, {
    int chunkSize = maxWhereInChunkSize,
  }) {
    final safeSize = chunkSize <= 0 ? maxWhereInChunkSize : chunkSize;
    final seen = <String>{};
    final uniqueIds = <String>[];
    for (final id in rawIds) {
      final clean = id.trim();
      if (clean.isNotEmpty && seen.add(clean)) {
        uniqueIds.add(clean);
      }
    }

    final chunks = <SpotIdChunk>[];
    for (var i = 0; i < uniqueIds.length; i += safeSize) {
      final end = (i + safeSize > uniqueIds.length)
          ? uniqueIds.length
          : i + safeSize;
      chunks.add(uniqueIds.sublist(i, end));
    }
    return chunks;
  }

  static List<LikedSpotRefRecord> mergeAndSortRecords(
    List<LikedSpotRefRecord> records,
  ) {
    final latestBySpotId = <String, LikedSpotRefRecord>{};
    for (final record in records) {
      final id = record.spotId.trim();
      if (id.isEmpty) continue;
      final normalized = LikedSpotRefRecord(
        spotId: id,
        likedAt: record.likedAt,
        sourceCollection: record.sourceCollection,
      );
      final existing = latestBySpotId[id];
      if (existing == null) {
        latestBySpotId[id] = normalized;
      } else {
        final existingTime = existing.likedAt;
        final newTime = normalized.likedAt;
        if (existingTime == null && newTime != null) {
          latestBySpotId[id] = normalized;
        } else if (existingTime != null &&
            newTime != null &&
            newTime.isAfter(existingTime)) {
          latestBySpotId[id] = normalized;
        }
      }
    }

    final merged = latestBySpotId.values.toList();
    merged.sort((a, b) {
      final aTime = a.likedAt;
      final bTime = b.likedAt;
      if (aTime == null && bTime == null) {
        return a.spotId.compareTo(b.spotId);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return merged;
  }

  static List<LikedSpotRefRecord> detectOrphanRecords({
    required List<LikedSpotRefRecord> requestedRecords,
    required Set<String> existingSpotIds,
  }) {
    return requestedRecords
        .where((record) => !existingSpotIds.contains(record.spotId))
        .toList();
  }

  static DateTime? parseTimestamp(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}

abstract class LikedSpotsGateway {
  Future<List<LikedSpotItem>> fetchLikedSpots({
    required String userId,
    bool cleanupOrphans = false,
  });
}

class FirestoreLikedSpotsRepository implements LikedSpotsGateway {
  FirestoreLikedSpotsRepository({
    this.firestore,
    this.enableCollectionGroupFallback = false,
  });

  final FirebaseFirestore? firestore;
  final bool enableCollectionGroupFallback;
  bool _collectionGroupIndexMissing = false;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<LikedSpotItem>> fetchLikedSpots({
    required String userId,
    bool cleanupOrphans = false,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw const LikedSpotsException(
        'Vui lòng đăng nhập để xem danh sách địa điểm yêu thích.',
        code: 'unauthenticated',
      );
    }

    try {
      final collectedRecords = <LikedSpotRefRecord>[];

      final primaryRecords = await _readUserSubcollection(
        userId: cleanUserId,
        subcollection: 'likedSpots',
        throwOnError: true,
      );
      collectedRecords.addAll(primaryRecords);

      final legacyUserRecords = await _readUserSubcollection(
        userId: cleanUserId,
        subcollection: 'likes',
        throwOnError: false,
      );
      collectedRecords.addAll(legacyUserRecords);

      if (collectedRecords.isEmpty &&
          enableCollectionGroupFallback &&
          !_collectionGroupIndexMissing) {
        final groupRecords = await _readCollectionGroupLikes(cleanUserId);
        collectedRecords.addAll(groupRecords);
      }

      final orderedRecords =
          LikedSpotsLogic.mergeAndSortRecords(collectedRecords);
      if (orderedRecords.isEmpty) {
        return const [];
      }

      final chunks = LikedSpotsLogic.chunkSpotIds(
        orderedRecords.map((r) => r.spotId).toList(),
      );

      final snapshots = await Future.wait(
        chunks.map(
          (chunk) => _db
              .collection('spots')
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        ),
      );

      final spotDataById = <String, FirestoreMap>{};
      for (final querySnap in snapshots) {
        for (final doc in querySnap.docs) {
          spotDataById[doc.id] = doc.data();
        }
      }

      final items = <LikedSpotItem>[];
      for (final record in orderedRecords) {
        final spotData = spotDataById[record.spotId];
        if (spotData != null) {
          items.add(
            LikedSpotItem.fromFirestore(
              record.spotId,
              spotData,
              likedAt: record.likedAt,
            ),
          );
        }
      }

      if (cleanupOrphans) {
        final orphans = LikedSpotsLogic.detectOrphanRecords(
          requestedRecords: orderedRecords,
          existingSpotIds: spotDataById.keys.toSet(),
        );
        if (orphans.isNotEmpty) {
          _cleanupOrphansBestEffort(cleanUserId, orphans);
        }
      }

      return items;
    } on LikedSpotsException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LikedSpotsRepository] fetchLikedSpots failed (${e.code}): ${e.message}',
        );
      }
      throw LikedSpotsException(
        LikedSpotsErrorMapper.map(e),
        code: e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LikedSpotsRepository] unexpected error: $e');
      }
      throw const LikedSpotsException(
        'Không thể tải danh sách địa điểm yêu thích. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  Future<List<LikedSpotRefRecord>> _readUserSubcollection({
    required String userId,
    required String subcollection,
    required bool throwOnError,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection(subcollection)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final explicitSpotId = (data['spotId'] as String?)?.trim() ?? '';
        final resolvedSpotId =
            explicitSpotId.isNotEmpty ? explicitSpotId : doc.id;
        return LikedSpotRefRecord(
          spotId: resolvedSpotId,
          likedAt: LikedSpotsLogic.parseTimestamp(
            data['createdAt'] ?? data['likedAt'],
          ),
          sourceCollection: subcollection,
        );
      }).toList();
    } catch (e) {
      if (throwOnError) {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint(
          '[LikedSpotsRepository] optional read users/$userId/$subcollection skipped: $e',
        );
      }
      return const [];
    }
  }

  Future<List<LikedSpotRefRecord>> _readCollectionGroupLikes(
    String userId,
  ) async {
    try {
      final snap = await _db
          .collectionGroup('likes')
          .where('userId', isEqualTo: userId)
          .get();

      final records = <LikedSpotRefRecord>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final explicitSpotId = (data['spotId'] as String?)?.trim() ?? '';
        final parentSpotId = doc.reference.parent.parent?.id ?? '';
        final resolvedSpotId =
            explicitSpotId.isNotEmpty ? explicitSpotId : parentSpotId;
        if (resolvedSpotId.isEmpty) continue;
        records.add(
          LikedSpotRefRecord(
            spotId: resolvedSpotId,
            likedAt: LikedSpotsLogic.parseTimestamp(
              data['createdAt'] ?? data['likedAt'],
            ),
            sourceCollection: 'collectionGroup',
          ),
        );
      }
      return records;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        _collectionGroupIndexMissing = true;
      }
      if (kDebugMode) {
        debugPrint(
          '[LikedSpotsRepository] fallback collectionGroup(likes) skipped: $e',
        );
      }
      return const [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LikedSpotsRepository] fallback collectionGroup(likes) skipped: $e',
        );
      }
      return const [];
    }
  }

  void _cleanupOrphansBestEffort(
    String userId,
    List<LikedSpotRefRecord> orphans,
  ) {
    for (final orphan in orphans) {
      if (orphan.sourceCollection != 'likedSpots' &&
          orphan.sourceCollection != 'likes') {
        continue;
      }
      _db
          .collection('users')
          .doc(userId)
          .collection(orphan.sourceCollection)
          .doc(orphan.spotId)
          .delete()
          .catchError((_) {});
    }
  }
}