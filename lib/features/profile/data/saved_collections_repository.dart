import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef FirestoreDataMap = Map<String, dynamic>;
typedef SpotDataByIdMap = Map<String, FirestoreDataMap>;
typedef SavedSpotByIdMap = Map<String, SavedSpotItem>;
typedef SavedSpotIdChunk = List<String>;
typedef SavedSpotRefList = List<SavedSpotRefRecord>;
typedef SavedSpotList = List<SavedSpotItem>;
typedef SpotCollectionList = List<SpotCollectionModel>;

class SavedCollectionsException implements Exception {
  const SavedCollectionsException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class CollectionIconOption {
  const CollectionIconOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class SavedSpotRefRecord {
  const SavedSpotRefRecord({
    required this.spotId,
    this.savedAt,
    this.sourceCollection = 'savedSpots',
  });

  final String spotId;
  final DateTime? savedAt;
  final String sourceCollection;
}

class SavedSpotItem {
  const SavedSpotItem({
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
    this.bestTimeTag = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.savedAt,
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
  final String bestTimeTag;
  final double latitude;
  final double longitude;
  final DateTime? savedAt;

  bool get hasRating => ratingCount > 0 || ratingAvg > 0;

  bool get hasValidCoordinates {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  factory SavedSpotItem.fromFirestore(
    String id,
    FirestoreDataMap data, {
    DateTime? savedAt,
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

    final rawLikes = data['likesCount'] ?? data['likeCount'];
    final likes = rawLikes is num ? rawLikes.toInt() : 0;
    final rawRatingAvg = data['ratingAvg'] ?? data['averageRating'];
    final ratingAvg = rawRatingAvg is num ? rawRatingAvg.toDouble() : 0.0;
    final rawRatingCount =
        data['ratingCount'] ?? data['reviewsCount'] ?? data['commentsCount'];
    final ratingCount = rawRatingCount is num ? rawRatingCount.toInt() : 0;

    final rawLat = data['latitude'];
    final parsedLat =
        (rawLat is num && !rawLat.toDouble().isNaN) ? rawLat.toDouble() : 0.0;
    final rawLng = data['longitude'];
    final parsedLng =
        (rawLng is num && !rawLng.toDouble().isNaN) ? rawLng.toDouble() : 0.0;

    return SavedSpotItem(
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
      bestTimeTag: ((data['bestTimeTag'] as String?) ?? '').trim(),
      latitude: parsedLat,
      longitude: parsedLng,
      savedAt: savedAt,
    );
  }
}

class SpotCollectionModel {
  const SpotCollectionModel({
    required this.id,
    required this.name,
    this.description = '',
    this.iconKey = 'trip',
    this.spotIds = const [],
    this.generatedItinerary = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String iconKey;
  final List<String> spotIds;
  final String generatedItinerary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SpotCollectionModel copyWith({
    String? name,
    String? description,
    String? iconKey,
    List<String>? spotIds,
    String? generatedItinerary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpotCollectionModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      spotIds: spotIds ?? this.spotIds,
      generatedItinerary: generatedItinerary ?? this.generatedItinerary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SpotCollectionModel.fromFirestore(
    String id,
    FirestoreDataMap data,
  ) {
    final rawIds = data['spotIds'];
    final uniqueIds = <String>[];
    final seen = <String>{};
    if (rawIds is List) {
      for (final entry in rawIds) {
        if (entry is String) {
          final clean = entry.trim();
          if (clean.isNotEmpty && seen.add(clean)) {
            uniqueIds.add(clean);
          }
        }
      }
    }

    final rawName = ((data['name'] as String?) ?? '').trim();
    final rawIcon = ((data['iconKey'] as String?) ?? '').trim();

    return SpotCollectionModel(
      id: id,
      name: rawName.isNotEmpty ? rawName : 'Bộ sưu tập chưa đặt tên',
      description: ((data['description'] as String?) ?? '').trim(),
      iconKey: rawIcon.isNotEmpty ? rawIcon : 'trip',
      spotIds: uniqueIds,
      generatedItinerary:
          ((data['generatedItinerary'] as String?) ?? '').trim(),
      createdAt: SavedCollectionsLogic.parseTimestamp(data['createdAt']),
      updatedAt: SavedCollectionsLogic.parseTimestamp(data['updatedAt']),
    );
  }
}

class SavedCollectionsBundle {
  const SavedCollectionsBundle({
    required this.savedSpots,
    required this.collections,
    this.allSpotsById = const {},
  });

  final SavedSpotList savedSpots;
  final SpotCollectionList collections;
  final SavedSpotByIdMap allSpotsById;
}

class CollectionAiReadiness {
  const CollectionAiReadiness({
    required this.spotCount,
    required this.isReady,
    required this.statusMessage,
  });

  final int spotCount;
  final bool isReady;
  final String statusMessage;
}

class SavedCollectionsErrorMapper {
  static String map(
    Object error, {
    String fallback =
        'Không thể xử lý danh sách đã lưu lúc này. Vui lòng thử lại.',
  }) {
    if (error is SavedCollectionsException) {
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
        return 'Bạn chưa có quyền truy cập mục Đã lưu. Vui lòng kiểm tra phiên đăng nhập.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'not-found':
        return 'Bộ sưu tập hoặc địa điểm này không còn tồn tại.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Mất kết nối mạng hoặc máy chủ phản hồi chậm. Vui lòng thử lại.';
      default:
        return fallback;
    }
  }

  static String? _extractCode(String raw) {
    if (raw.contains('permission-denied')) return 'permission-denied';
    if (raw.contains('unauthenticated')) return 'unauthenticated';
    if (raw.contains('not-found')) return 'not-found';
    if (raw.contains('unavailable') || raw.contains('network-request-failed')) {
      return 'unavailable';
    }
    if (raw.contains('deadline-exceeded')) return 'deadline-exceeded';
    return null;
  }
}

class SavedCollectionsLogic {
  static const int maxWhereInChunkSize = 10;
  static const int maxCollectionNameLength = 50;
  static const int maxDescriptionLength = 150;
  static const int minAiItinerarySpots = 3;
  static const int maxAiItinerarySpots = 8;

  static const Set<String> reservedCollectionNames = {
    'da luu',
    'saved',
  };

  static const List<CollectionIconOption> iconOptions = [
    CollectionIconOption(key: 'trip', label: 'Chuyến đi'),
    CollectionIconOption(key: 'beach', label: 'Biển'),
    CollectionIconOption(key: 'food', label: 'Ẩm thực'),
    CollectionIconOption(key: 'coffee', label: 'Cà phê'),
    CollectionIconOption(key: 'view', label: 'Cảnh đẹp'),
    CollectionIconOption(key: 'bookmark', label: 'Khác'),
  ];

  static const List<String> quickNameSuggestions = [
    'Du lịch cuối tuần',
    'Quán ngon nhất định thử',
    'Điểm săn hoàng hôn',
    'Cà phê view đẹp',
  ];

  static const Map<String, String> _vietnameseCharMap = {
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };

  static String normalizeText(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_vietnameseCharMap[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isReservedCollectionName(String rawName) {
    return reservedCollectionNames.contains(normalizeText(rawName));
  }

  static String? validateCollectionName(
    String? rawName, {
    SpotCollectionList existing = const [],
    String? excludingCollectionId,
  }) {
    final clean = (rawName ?? '').trim();
    if (clean.isEmpty) {
      return 'Vui lòng nhập tên bộ sưu tập';
    }
    if (clean.length > maxCollectionNameLength) {
      return 'Tên bộ sưu tập tối đa $maxCollectionNameLength ký tự';
    }

    final normalizedCandidate = normalizeText(clean);
    if (reservedCollectionNames.contains(normalizedCandidate)) {
      return 'Tên "Đã lưu" là mục mặc định, vui lòng đặt tên bộ sưu tập khác';
    }

    for (final col in existing) {
      if (excludingCollectionId != null && col.id == excludingCollectionId) {
        continue;
      }
      if (normalizeText(col.name) == normalizedCandidate) {
        return 'Bạn đã có bộ sưu tập trùng tên này';
      }
    }
    return null;
  }

  static String? validateDescription(String? rawDescription) {
    final clean = (rawDescription ?? '').trim();
    if (clean.length > maxDescriptionLength) {
      return 'Mô tả tối đa $maxDescriptionLength ký tự';
    }
    return null;
  }

  static List<SavedSpotIdChunk> chunkSpotIds(
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

    final chunks = <SavedSpotIdChunk>[];
    for (var i = 0; i < uniqueIds.length; i += safeSize) {
      final end = (i + safeSize > uniqueIds.length)
          ? uniqueIds.length
          : i + safeSize;
      chunks.add(uniqueIds.sublist(i, end));
    }
    return chunks;
  }

  static SavedSpotRefList mergeAndSortSavedRecords(SavedSpotRefList records) {
    final latestBySpotId = <String, SavedSpotRefRecord>{};
    for (final record in records) {
      final id = record.spotId.trim();
      if (id.isEmpty) continue;
      final normalized = SavedSpotRefRecord(
        spotId: id,
        savedAt: record.savedAt,
        sourceCollection: record.sourceCollection,
      );
      final existing = latestBySpotId[id];
      if (existing == null) {
        latestBySpotId[id] = normalized;
      } else {
        final existingTime = existing.savedAt;
        final newTime = normalized.savedAt;
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
      final aTime = a.savedAt;
      final bTime = b.savedAt;
      if (aTime == null && bTime == null) return a.spotId.compareTo(b.spotId);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return merged;
  }

  static SpotCollectionList sortCollections(SpotCollectionList collections) {
    final sorted = List<SpotCollectionModel>.from(collections);
    sorted.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      if (aTime == null && bTime == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  static bool matchesSpotQuery(String rawQuery, SavedSpotItem spot) {
    final query = normalizeText(rawQuery);
    if (query.isEmpty) return true;
    final haystack = normalizeText(
      '${spot.title} ${spot.category} ${spot.addressText} ${spot.authorName} ${spot.priceTag}',
    );
    return haystack.contains(query);
  }

  static bool matchesCollectionQuery(
    String rawQuery,
    SpotCollectionModel collection,
    SavedSpotByIdMap spotMap,
  ) {
    final query = normalizeText(rawQuery);
    if (query.isEmpty) return true;
    if (normalizeText('${collection.name} ${collection.description}')
        .contains(query)) {
      return true;
    }
    for (final spotId in collection.spotIds) {
      final spot = spotMap[spotId];
      if (spot != null && matchesSpotQuery(rawQuery, spot)) {
        return true;
      }
    }
    return false;
  }

  static List<String> resolveCoverThumbnails({
    required SpotCollectionModel collection,
    required SavedSpotByIdMap spotMap,
    int maxCount = 4,
  }) {
    final thumbs = <String>[];
    for (final spotId in collection.spotIds) {
      final spot = spotMap[spotId];
      if (spot != null && spot.thumbnailUrl.isNotEmpty) {
        thumbs.add(spot.thumbnailUrl);
        if (thumbs.length >= maxCount) break;
      }
    }
    return thumbs;
  }

  static int countCollectionsForSpot({
    required String spotId,
    required SpotCollectionList collections,
  }) {
    var count = 0;
    for (final col in collections) {
      if (col.spotIds.contains(spotId)) count++;
    }
    return count;
  }

  static CollectionAiReadiness evaluateAiReadiness(int validSpotCount) {
    final safeCount = validSpotCount < 0 ? 0 : validSpotCount;
    if (safeCount < minAiItinerarySpots) {
      final remaining = minAiItinerarySpots - safeCount;
      return CollectionAiReadiness(
        spotCount: safeCount,
        isReady: false,
        statusMessage:
            'Thêm ít nhất $remaining địa điểm nữa để dùng AI Xếp lịch trình ($safeCount/$minAiItinerarySpots–$maxAiItinerarySpots).',
      );
    }
    if (safeCount > maxAiItinerarySpots) {
      return CollectionAiReadiness(
        spotCount: safeCount,
        isReady: true,
        statusMessage:
            'Có $safeCount địa điểm — AI sẽ chọn tối ưu $maxAiItinerarySpots điểm phù hợp nhất cho lịch trình.',
      );
    }
    return CollectionAiReadiness(
      spotCount: safeCount,
      isReady: true,
      statusMessage:
          'Sẵn sàng tạo lịch trình du lịch thông minh từ $safeCount địa điểm trong bộ sưu tập này.',
    );
  }

  static double resolveSavedCardExtent(double textScaleFactor) {
    final safeScale = textScaleFactor.clamp(1.0, 1.4);
    return 224.0 + ((safeScale - 1.0) * 68.0);
  }

  static double resolveCollectionCardExtent(double textScaleFactor) {
    final safeScale = textScaleFactor.clamp(1.0, 1.4);
    return 218.0 + ((safeScale - 1.0) * 62.0);
  }

  static DateTime? parseTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

abstract class SavedCollectionsGateway {
  Future<SavedCollectionsBundle> fetchSavedBundle({
    required String userId,
    bool cleanupOrphans = false,
  });

  Future<void> saveSpotToDefault({
    required String userId,
    required String spotId,
  });

  Future<void> unsaveUncategorizedSpot({
    required String userId,
    required String spotId,
  });

  Future<SpotCollectionModel> createCollection({
    required String userId,
    required String name,
    String description = '',
    String iconKey = 'trip',
    List<String> initialSpotIds = const [],
  });

  Future<void> updateCollection({
    required String userId,
    required String collectionId,
    required String name,
    String description = '',
    String iconKey = 'trip',
  });

  Future<void> deleteCollection({
    required String userId,
    required String collectionId,
  });

  Future<void> setCollectionSpots({
    required String userId,
    required String collectionId,
    required List<String> spotIds,
  });

  Future<void> setSpotCollections({
    required String userId,
    required String spotId,
    required Set<String> targetCollectionIds,
    required SpotCollectionList currentCollections,
  });

  Future<void> removeSpotFromCollection({
    required String userId,
    required String collectionId,
    required String spotId,
    required bool isLastCollection,
  });

  Future<void> saveGeneratedItinerary({
    required String userId,
    required String collectionId,
    required String generatedItinerary,
  });
}

class FirestoreSavedCollectionsRepository implements SavedCollectionsGateway {
  FirestoreSavedCollectionsRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<SavedCollectionsBundle> fetchSavedBundle({
    required String userId,
    bool cleanupOrphans = false,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) {
      throw const SavedCollectionsException(
        'Vui lòng đăng nhập để xem mục Đã lưu.',
        code: 'unauthenticated',
      );
    }

    try {
      final results = await Future.wait<Object>([
        _readSavedRefs(
          userId: cleanUid,
          subcollection: 'savedSpots',
          throwOnError: true,
        ),
        _readSavedRefs(
          userId: cleanUid,
          subcollection: 'saved_spots',
          throwOnError: false,
        ),
        _db.collection('users').doc(cleanUid).collection('collections').get(),
      ]);

      final primaryRefs = results[0] as SavedSpotRefList;
      final legacyRefs = results[1] as SavedSpotRefList;
      final collectionsSnap = results[2] as QuerySnapshot<FirestoreDataMap>;

      final rawCollections = collectionsSnap.docs
          .map((doc) => SpotCollectionModel.fromFirestore(doc.id, doc.data()))
          .where(
            (col) => !SavedCollectionsLogic.isReservedCollectionName(col.name),
          )
          .toList();

      final combinedSavedRefs = <SavedSpotRefRecord>[
        ...primaryRefs,
        ...legacyRefs,
      ];
      final orderedSavedRefs =
          SavedCollectionsLogic.mergeAndSortSavedRecords(combinedSavedRefs);

      final savedRefSpotIds = orderedSavedRefs.map((r) => r.spotId).toSet();
      final missingSavedAtById = <String, DateTime?>{};
      for (final col in rawCollections) {
        final colTime = col.updatedAt ?? col.createdAt;
        for (final spotId in col.spotIds) {
          if (savedRefSpotIds.contains(spotId)) continue;
          if (!missingSavedAtById.containsKey(spotId)) {
            missingSavedAtById[spotId] = colTime;
          } else {
            final existingTime = missingSavedAtById[spotId];
            if (existingTime == null && colTime != null) {
              missingSavedAtById[spotId] = colTime;
            } else if (existingTime != null &&
                colTime != null &&
                colTime.isAfter(existingTime)) {
              missingSavedAtById[spotId] = colTime;
            }
          }
        }
      }

      final missingSavedRefs = missingSavedAtById.entries
          .map(
            (entry) => SavedSpotRefRecord(
              spotId: entry.key,
              savedAt: entry.value,
              sourceCollection: 'collections',
            ),
          )
          .toList();

      final orderedAllRefs = SavedCollectionsLogic.mergeAndSortSavedRecords([
        ...orderedSavedRefs,
        ...missingSavedRefs,
      ]);

      final allSpotIds = orderedAllRefs.map((ref) => ref.spotId).toList();
      final spotDataById = await _fetchSpotsByIds(allSpotIds);

      final cleanedCollections = rawCollections.map((col) {
        final validIds =
            col.spotIds.where((id) => spotDataById.containsKey(id)).toList();
        return col.copyWith(spotIds: validIds);
      }).toList();

      final allSpotsById = <String, SavedSpotItem>{};
      final savedAtBySpotId = <String, DateTime?>{
        for (final ref in orderedAllRefs) ref.spotId: ref.savedAt,
      };

      for (final entry in spotDataById.entries) {
        allSpotsById[entry.key] = SavedSpotItem.fromFirestore(
          entry.key,
          entry.value,
          savedAt: savedAtBySpotId[entry.key],
        );
      }

      final allSavedSpots = <SavedSpotItem>[];
      for (final ref in orderedAllRefs) {
        final spot = allSpotsById[ref.spotId];
        if (spot != null) {
          allSavedSpots.add(spot);
        }
      }

      final existingSpotIds = spotDataById.keys.toSet();
      _syncMissingSavedRefsBestEffort(
        userId: cleanUid,
        missingRefs: missingSavedRefs,
        existingSpotIds: existingSpotIds,
      );

      if (cleanupOrphans) {
        _cleanupOrphansBestEffort(
          userId: cleanUid,
          requestedRefs: orderedSavedRefs,
          rawCollections: rawCollections,
          existingSpotIds: existingSpotIds,
        );
      }

      return SavedCollectionsBundle(
        savedSpots: allSavedSpots,
        collections: SavedCollectionsLogic.sortCollections(cleanedCollections),
        allSpotsById: allSpotsById,
      );
    } on SavedCollectionsException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SavedCollectionsRepository] fetchSavedBundle failed (${e.code}): ${e.message}',
        );
      }
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SavedCollectionsRepository] unexpected error: $e');
      }
      throw const SavedCollectionsException(
        'Không thể tải mục Đã lưu lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> saveSpotToDefault({
    required String userId,
    required String spotId,
  }) async {
    final cleanUid = userId.trim();
    final cleanSpotId = spotId.trim();
    if (cleanUid.isEmpty || cleanSpotId.isEmpty) {
      throw const SavedCollectionsException(
        'Vui lòng đăng nhập để lưu địa điểm.',
        code: 'unauthenticated',
      );
    }

    try {
      final docRef = _db
          .collection('users')
          .doc(cleanUid)
          .collection('savedSpots')
          .doc(cleanSpotId);
      final existing = await docRef.get();
      if (existing.exists) return;

      await docRef.set(
        {
          'spotId': cleanSpotId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể lưu địa điểm lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> unsaveUncategorizedSpot({
    required String userId,
    required String spotId,
  }) async {
    final cleanUid = userId.trim();
    final cleanSpotId = spotId.trim();
    if (cleanUid.isEmpty || cleanSpotId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được địa điểm cần bỏ lưu.',
        code: 'invalid-argument',
      );
    }

    try {
      await _deleteSpotEverywhere(userId: cleanUid, spotId: cleanSpotId);
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể bỏ lưu địa điểm lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<SpotCollectionModel> createCollection({
    required String userId,
    required String name,
    String description = '',
    String iconKey = 'trip',
    List<String> initialSpotIds = const [],
  }) async {
    final cleanUid = userId.trim();
    final cleanName = name.trim();
    final cleanDesc = description.trim();
    final cleanIcon = iconKey.trim().isEmpty ? 'trip' : iconKey.trim();

    if (cleanUid.isEmpty) {
      throw const SavedCollectionsException(
        'Vui lòng đăng nhập để tạo bộ sưu tập.',
        code: 'unauthenticated',
      );
    }
    final nameErr = SavedCollectionsLogic.validateCollectionName(cleanName);
    if (nameErr != null) {
      throw SavedCollectionsException(nameErr, code: 'invalid-argument');
    }
    final descErr = SavedCollectionsLogic.validateDescription(cleanDesc);
    if (descErr != null) {
      throw SavedCollectionsException(descErr, code: 'invalid-argument');
    }

    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final id in initialSpotIds) {
      final clean = id.trim();
      if (clean.isNotEmpty && seen.add(clean)) {
        uniqueIds.add(clean);
      }
    }

    try {
      final userRef = _db.collection('users').doc(cleanUid);
      final colRef = userRef.collection('collections').doc();
      final now = DateTime.now();

      final batch = _db.batch();
      batch.set(colRef, {
        'id': colRef.id,
        'name': cleanName,
        'description': cleanDesc,
        'iconKey': cleanIcon,
        'spotIds': uniqueIds,
        'generatedItinerary': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (uniqueIds.isNotEmpty) {
        await _ensureSavedSpotsInBatch(
          userRef: userRef,
          batch: batch,
          spotIds: uniqueIds,
        );
      }

      await batch.commit();

      return SpotCollectionModel(
        id: colRef.id,
        name: cleanName,
        description: cleanDesc,
        iconKey: cleanIcon,
        spotIds: uniqueIds,
        createdAt: now,
        updatedAt: now,
      );
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể tạo bộ sưu tập lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> updateCollection({
    required String userId,
    required String collectionId,
    required String name,
    String description = '',
    String iconKey = 'trip',
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    final cleanName = name.trim();
    final cleanDesc = description.trim();
    final cleanIcon = iconKey.trim().isEmpty ? 'trip' : iconKey.trim();

    if (cleanUid.isEmpty || cleanColId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được bộ sưu tập cần cập nhật.',
        code: 'invalid-argument',
      );
    }
    final nameErr = SavedCollectionsLogic.validateCollectionName(cleanName);
    if (nameErr != null) {
      throw SavedCollectionsException(nameErr, code: 'invalid-argument');
    }
    final descErr = SavedCollectionsLogic.validateDescription(cleanDesc);
    if (descErr != null) {
      throw SavedCollectionsException(descErr, code: 'invalid-argument');
    }

    try {
      await _db
          .collection('users')
          .doc(cleanUid)
          .collection('collections')
          .doc(cleanColId)
          .update({
        'name': cleanName,
        'description': cleanDesc,
        'iconKey': cleanIcon,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể cập nhật bộ sưu tập lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> deleteCollection({
    required String userId,
    required String collectionId,
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    if (cleanUid.isEmpty || cleanColId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được bộ sưu tập cần xóa.',
        code: 'invalid-argument',
      );
    }

    try {
      final userRef = _db.collection('users').doc(cleanUid);
      final colRef = userRef.collection('collections').doc(cleanColId);
      final colSnap = await colRef.get();

      final removedSpotIds = <String>{};
      final rawIds = colSnap.data()?['spotIds'];
      if (rawIds is List) {
        for (final entry in rawIds) {
          if (entry is String && entry.trim().isNotEmpty) {
            removedSpotIds.add(entry.trim());
          }
        }
      }

      final ops = <void Function(WriteBatch)>[
        (batch) => batch.delete(colRef),
      ];

      if (removedSpotIds.isNotEmpty) {
        final allColsSnap = await userRef.collection('collections').get();
        for (final doc in allColsSnap.docs) {
          if (doc.id == cleanColId) continue;
          final docSpotIds = doc.data()['spotIds'];
          if (docSpotIds is! List) continue;
          final overlapping = <String>[];
          for (final entry in docSpotIds) {
            if (entry is String && removedSpotIds.contains(entry.trim())) {
              overlapping.add(entry);
            }
          }
          if (overlapping.isNotEmpty) {
            ops.add(
              (batch) => batch.update(doc.reference, {
                'spotIds': FieldValue.arrayRemove(overlapping),
                'updatedAt': FieldValue.serverTimestamp(),
              }),
            );
          }
        }

        for (final spotId in removedSpotIds) {
          ops.add(
            (batch) =>
                batch.delete(userRef.collection('savedSpots').doc(spotId)),
          );
          ops.add(
            (batch) =>
                batch.delete(userRef.collection('saved_spots').doc(spotId)),
          );
        }
      }

      const batchLimit = 400;
      for (var i = 0; i < ops.length; i += batchLimit) {
        final end =
            (i + batchLimit < ops.length) ? i + batchLimit : ops.length;
        final batch = _db.batch();
        for (var j = i; j < end; j++) {
          ops[j](batch);
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể xóa bộ sưu tập lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> setCollectionSpots({
    required String userId,
    required String collectionId,
    required List<String> spotIds,
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    if (cleanUid.isEmpty || cleanColId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được bộ sưu tập cần cập nhật.',
        code: 'invalid-argument',
      );
    }

    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final id in spotIds) {
      final clean = id.trim();
      if (clean.isNotEmpty && seen.add(clean)) {
        uniqueIds.add(clean);
      }
    }

    try {
      final userRef = _db.collection('users').doc(cleanUid);
      final batch = _db.batch();
      batch.update(userRef.collection('collections').doc(cleanColId), {
        'spotIds': uniqueIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (uniqueIds.isNotEmpty) {
        await _ensureSavedSpotsInBatch(
          userRef: userRef,
          batch: batch,
          spotIds: uniqueIds,
        );
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể cập nhật danh sách địa điểm trong bộ sưu tập.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> setSpotCollections({
    required String userId,
    required String spotId,
    required Set<String> targetCollectionIds,
    required SpotCollectionList currentCollections,
  }) async {
    final cleanUid = userId.trim();
    final cleanSpotId = spotId.trim();
    if (cleanUid.isEmpty || cleanSpotId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được địa điểm cần phân loại.',
        code: 'invalid-argument',
      );
    }

    try {
      final userRef = _db.collection('users').doc(cleanUid);
      final batch = _db.batch();

      await _ensureSavedSpotsInBatch(
        userRef: userRef,
        batch: batch,
        spotIds: [cleanSpotId],
      );

      for (final col in currentCollections) {
        final currentlyIn = col.spotIds.contains(cleanSpotId);
        final shouldBeIn = targetCollectionIds.contains(col.id);
        if (currentlyIn == shouldBeIn) continue;

        final colRef = userRef.collection('collections').doc(col.id);
        batch.update(colRef, {
          'spotIds': shouldBeIn
              ? FieldValue.arrayUnion([cleanSpotId])
              : FieldValue.arrayRemove([cleanSpotId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể lưu phân loại bộ sưu tập lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> removeSpotFromCollection({
    required String userId,
    required String collectionId,
    required String spotId,
    required bool isLastCollection,
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    final cleanSpotId = spotId.trim();
    if (cleanUid.isEmpty || cleanColId.isEmpty || cleanSpotId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được địa điểm cần xóa.',
        code: 'invalid-argument',
      );
    }

    try {
      await _deleteSpotEverywhere(userId: cleanUid, spotId: cleanSpotId);
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể xóa địa điểm lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> saveGeneratedItinerary({
    required String userId,
    required String collectionId,
    required String generatedItinerary,
  }) async {
    final cleanUid = userId.trim();
    final cleanColId = collectionId.trim();
    if (cleanUid.isEmpty || cleanColId.isEmpty) {
      throw const SavedCollectionsException(
        'Không xác định được bộ sưu tập cần lưu lịch trình.',
        code: 'invalid-argument',
      );
    }

    try {
      await _db
          .collection('users')
          .doc(cleanUid)
          .collection('collections')
          .doc(cleanColId)
          .update({
        'generatedItinerary': generatedItinerary.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SavedCollectionsException(
        SavedCollectionsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const SavedCollectionsException(
        'Không thể lưu lịch trình AI lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  Future<void> _deleteSpotEverywhere({
    required String userId,
    required String spotId,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final matchingCols = await userRef
        .collection('collections')
        .where('spotIds', arrayContains: spotId)
        .get();

    final batch = _db.batch();
    batch.delete(userRef.collection('savedSpots').doc(spotId));
    batch.delete(userRef.collection('saved_spots').doc(spotId));

    for (final doc in matchingCols.docs) {
      batch.update(doc.reference, {
        'spotIds': FieldValue.arrayRemove([spotId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _ensureSavedSpotsInBatch({
    required DocumentReference<FirestoreDataMap> userRef,
    required WriteBatch batch,
    required Iterable<String> spotIds,
  }) async {
    final cleanIds = <String>{};
    for (final id in spotIds) {
      final clean = id.trim();
      if (clean.isNotEmpty) {
        cleanIds.add(clean);
      }
    }
    if (cleanIds.isEmpty) return;

    final savedCol = userRef.collection('savedSpots');
    final snaps = await Future.wait(
      cleanIds.map((id) => savedCol.doc(id).get()),
    );

    for (final snap in snaps) {
      if (!snap.exists) {
        batch.set(
          snap.reference,
          {
            'spotId': snap.id,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }
  }

  Future<SavedSpotRefList> _readSavedRefs({
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
        final explicitId = (data['spotId'] as String?)?.trim() ?? '';
        return SavedSpotRefRecord(
          spotId: explicitId.isNotEmpty ? explicitId : doc.id,
          savedAt: SavedCollectionsLogic.parseTimestamp(
            data['createdAt'] ?? data['savedAt'],
          ),
          sourceCollection: subcollection,
        );
      }).toList();
    } catch (e) {
      if (throwOnError) rethrow;
      if (kDebugMode) {
        debugPrint(
          '[SavedCollectionsRepository] optional read $subcollection skipped: $e',
        );
      }
      return const [];
    }
  }

  Future<SpotDataByIdMap> _fetchSpotsByIds(List<String> spotIds) async {
    final chunks = SavedCollectionsLogic.chunkSpotIds(spotIds);
    if (chunks.isEmpty) return const {};

    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _db
            .collection('spots')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ),
    );

    final map = <String, FirestoreDataMap>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        map[doc.id] = doc.data();
      }
    }
    return map;
  }

  void _syncMissingSavedRefsBestEffort({
    required String userId,
    required SavedSpotRefList missingRefs,
    required Set<String> existingSpotIds,
  }) {
    final validMissing = missingRefs
        .where((ref) => existingSpotIds.contains(ref.spotId))
        .toList();
    if (validMissing.isEmpty) return;

    final userRef = _db.collection('users').doc(userId);
    const batchLimit = 400;
    for (var i = 0; i < validMissing.length; i += batchLimit) {
      final end = (i + batchLimit < validMissing.length)
          ? i + batchLimit
          : validMissing.length;
      final batch = _db.batch();
      for (var j = i; j < end; j++) {
        final ref = validMissing[j];
        batch.set(
          userRef.collection('savedSpots').doc(ref.spotId),
          {
            'spotId': ref.spotId,
            'createdAt': ref.savedAt != null
                ? Timestamp.fromDate(ref.savedAt!)
                : FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      batch.commit().catchError((_) {});
    }
  }

  void _cleanupOrphansBestEffort({
    required String userId,
    required SavedSpotRefList requestedRefs,
    required SpotCollectionList rawCollections,
    required Set<String> existingSpotIds,
  }) {
    final userRef = _db.collection('users').doc(userId);
    for (final ref in requestedRefs) {
      if (!existingSpotIds.contains(ref.spotId)) {
        userRef
            .collection(ref.sourceCollection)
            .doc(ref.spotId)
            .delete()
            .catchError((_) {});
      }
    }
    for (final col in rawCollections) {
      final validIds =
          col.spotIds.where((id) => existingSpotIds.contains(id)).toList();
      if (validIds.length != col.spotIds.length) {
        userRef
            .collection('collections')
            .doc(col.id)
            .update({'spotIds': validIds}).catchError((_) {});
      }
    }
  }
}