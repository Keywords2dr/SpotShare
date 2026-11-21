import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef FirestoreDataMap = Map<String, dynamic>;

class ExploreFeedException implements Exception {
  const ExploreFeedException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ExploreSpotSummary {
  const ExploreSpotSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.thumbnailUrl,
    required this.addressText,
    required this.bestTimeTag,
    required this.difficultyTag,
    required this.priceTag,
    required this.authorId,
    required this.authorName,
    required this.likesCount,
    required this.ratingAvg,
    required this.ratingCount,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String thumbnailUrl;
  final String addressText;
  final String bestTimeTag;
  final String difficultyTag;
  final String priceTag;
  final String authorId;
  final String authorName;
  final int likesCount;
  final double ratingAvg;
  final int ratingCount;
  final DateTime? createdAt;

  bool get hasRating => ratingCount > 0 || ratingAvg > 0;

  ExploreSpotSummary copyWith({
    String? title,
    String? description,
    String? category,
    String? thumbnailUrl,
    String? addressText,
    String? bestTimeTag,
    String? difficultyTag,
    String? priceTag,
    String? authorId,
    String? authorName,
    int? likesCount,
    double? ratingAvg,
    int? ratingCount,
    DateTime? createdAt,
  }) {
    return ExploreSpotSummary(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      addressText: addressText ?? this.addressText,
      bestTimeTag: bestTimeTag ?? this.bestTimeTag,
      difficultyTag: difficultyTag ?? this.difficultyTag,
      priceTag: priceTag ?? this.priceTag,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      likesCount: likesCount ?? this.likesCount,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ExploreSpotSummary.fromFirestore(
    String id,
    FirestoreDataMap data,
  ) {
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

    return ExploreSpotSummary(
      id: id,
      title: ((data['title'] as String?) ?? '').trim().isNotEmpty
          ? (data['title'] as String).trim()
          : 'Địa điểm chưa đặt tên',
      description: ((data['description'] as String?) ?? '').trim(),
      category: ((data['category'] as String?) ?? '').trim(),
      thumbnailUrl: thumb,
      addressText: ((data['addressText'] as String?) ?? '').trim(),
      bestTimeTag: ((data['bestTimeTag'] as String?) ?? '').trim(),
      difficultyTag: ((data['difficultyTag'] as String?) ?? '').trim(),
      priceTag: ((data['priceTag'] as String?) ?? '').trim(),
      authorId: ((data['authorId'] as String?) ?? '').trim(),
      authorName: ((data['authorName'] as String?) ?? '').trim(),
      likesCount: likes < 0 ? 0 : likes,
      ratingAvg: ratingAvg < 0 ? 0 : ratingAvg,
      ratingCount: ratingCount < 0 ? 0 : ratingCount,
      createdAt: ExploreFeedLogic.parseDateTime(data['createdAt']),
    );
  }
}

class ExploreUserHit {
  const ExploreUserHit({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String username;
  final String avatarUrl;

  String get handle => '@$username';
}

class ExploreFeedPage {
  const ExploreFeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ExploreSpotSummary> items;
  final bool hasMore;
  final Object? nextCursor;
}

class ExploreFeedFilterPresets {
  static const String allCategory = 'Tất cả';

  static const List<String> categories = [
    allCategory,
    'Bãi biển',
    'Cảnh đẹp / Check-in',
    'Món ăn ngon',
    'Quán cà phê view đẹp',
    'Di tích / Văn hóa',
  ];

  static const List<String> priceRanges = [
    'Miễn phí',
    '< 50k',
    '50k - 150k',
    '> 150k',
  ];

  static const List<String> bestTimes = [
    'Bình minh',
    'Sáng',
    'Trưa',
    'Hoàng hôn',
    'Tối',
    'Cả ngày',
  ];
}

class ExploreFeedErrorMapper {
  static String map(
    Object error, {
    String fallback = 'Không thể tải bảng tin lúc này. Vui lòng thử lại.',
  }) {
    if (error is ExploreFeedException) {
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
        return 'Bạn chưa có quyền xem bảng tin. Vui lòng kiểm tra phiên đăng nhập hoặc quy tắc Firestore.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
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
    if (raw.contains('unavailable') || raw.contains('network-request-failed')) {
      return 'unavailable';
    }
    if (raw.contains('deadline-exceeded')) return 'deadline-exceeded';
    return null;
  }
}

class ExploreFeedLogic {
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

  static int resolveGridCrossAxisCount(double maxWidth) {
    if (maxWidth >= 900) return 4;
    if (maxWidth >= 600) return 3;
    return 2;
  }

  static double resolveCardMainAxisExtent(double textScaleFactor) {
    final safeScale = textScaleFactor.clamp(1.0, 1.4);
    return 236.0 + ((safeScale - 1.0) * 75.0);
  }

  static List<ExploreSpotSummary> mergeHeadAndOlder({
    required List<ExploreSpotSummary> head,
    required List<ExploreSpotSummary> older,
  }) {
    final seen = <String>{};
    final merged = <ExploreSpotSummary>[];
    for (final item in head) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    for (final item in older) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    return merged;
  }

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

  static String normalizeCompact(String raw) {
    return normalizeText(raw).replaceAll(RegExp(r'[\s–—-]+'), '');
  }

  static bool isHandleQuery(String rawQuery) {
    return rawQuery.trim().startsWith('@');
  }

  static String extractHandle(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (!trimmed.startsWith('@')) return '';
    return trimmed
        .substring(1)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
  }

  static bool matchesCategory(String selectedCategory, String spotCategory) {
    final normalizedSelected = normalizeText(selectedCategory);
    if (normalizedSelected.isEmpty || normalizedSelected == 'tat ca') {
      return true;
    }
    final normalizedSpot = normalizeText(spotCategory);
    if (normalizedSpot.isEmpty) return false;
    if (normalizedSpot.contains(normalizedSelected) ||
        normalizedSelected.contains(normalizedSpot)) {
      return true;
    }
    if (normalizedSelected.contains('mon an') &&
        (normalizedSpot.contains('am thuc') ||
            normalizedSpot.contains('mon an'))) {
      return true;
    }
    if (normalizedSelected.contains('ca phe') &&
        (normalizedSpot.contains('ca phe') ||
            normalizedSpot.contains('cafe') ||
            normalizedSpot.contains('coffee'))) {
      return true;
    }
    if (normalizedSelected.contains('canh dep') &&
        (normalizedSpot.contains('canh dep') ||
            normalizedSpot.contains('check-in'))) {
      return true;
    }
    if (normalizedSelected.contains('di tich') &&
        (normalizedSpot.contains('di tich') ||
            normalizedSpot.contains('van hoa'))) {
      return true;
    }
    return false;
  }

  static bool matchesPrice(String? selectedPrice, String spotPriceTag) {
    if (selectedPrice == null || selectedPrice.trim().isEmpty) {
      return true;
    }
    final target = normalizeCompact(selectedPrice);
    final actual = normalizeCompact(spotPriceTag);
    if (actual.isEmpty) return false;
    return actual == target || actual.contains(target);
  }

  static bool matchesBestTime(String? selectedTime, String spotBestTimeTag) {
    if (selectedTime == null || selectedTime.trim().isEmpty) {
      return true;
    }
    final target = normalizeText(selectedTime);
    final actual = normalizeText(spotBestTimeTag);
    if (actual.isEmpty) return false;
    return actual.contains(target);
  }

  static bool matchesQuery(String rawQuery, ExploreSpotSummary spot) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return true;
    final query = isHandleQuery(trimmed)
        ? normalizeText(trimmed.substring(1))
        : normalizeText(trimmed);
    if (query.isEmpty) return true;

    final haystack = normalizeText(
      '${spot.title} ${spot.description} ${spot.addressText} '
      '${spot.category} ${spot.authorName} ${spot.priceTag} ${spot.bestTimeTag}',
    );
    return haystack.contains(query);
  }

  static double recommendationScore(
    ExploreSpotSummary spot, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final created = spot.createdAt;
    double recencyBonus = 0;
    double freshPostBoost = 0;

    if (created == null) {
      recencyBonus = 5.0;
      freshPostBoost = 48.0;
    } else {
      final ageMinutes = reference.difference(created).inMinutes;
      final clampedMinutes = ageMinutes < 0 ? 0 : ageMinutes;
      final ageHours = (clampedMinutes ~/ 60).clamp(0, 720);
      recencyBonus = (720 - ageHours) / 144.0;
      if (clampedMinutes <= 120) {
        freshPostBoost = (120 - clampedMinutes) * 0.4;
      }
    }

    return (spot.likesCount * 2.0) +
        (spot.ratingAvg * spot.ratingCount * 1.5) +
        recencyBonus +
        freshPostBoost;
  }

  static String formatRelativeTime(DateTime? dateTime, {DateTime? now}) {
    if (dateTime == null) return 'Vừa xong';
    final current = now ?? DateTime.now();
    final diff = current.difference(dateTime);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24 && current.day == dateTime.day) {
      return '${diff.inHours} giờ trước';
    }
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final yesterday = current.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return 'Hôm qua $hh:$mm';
    }
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mo = dateTime.month.toString().padLeft(2, '0');
    return '$dd/$mo';
  }

  static DateTime? parseDateTime(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

abstract class ExploreFeedGateway {
  Stream<List<ExploreSpotSummary>> watchLatestSpots({int limit = 12});

  Future<ExploreFeedPage> fetchPage({
    int limit = 12,
    Object? cursor,
  });

  Future<ExploreSpotSummary?> fetchSpotById(String spotId);

  Future<List<ExploreUserHit>> searchUsersByHandle(String rawHandle);
}

class FirestoreExploreFeedRepository implements ExploreFeedGateway {
  FirestoreExploreFeedRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<ExploreSpotSummary>> watchLatestSpots({int limit = 12}) {
    return _db
        .collection('spots')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ExploreSpotSummary.fromFirestore(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  @override
  Future<ExploreFeedPage> fetchPage({
    int limit = 12,
    Object? cursor,
  }) async {
    try {
      Query<FirestoreDataMap> query = _db
          .collection('spots')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (cursor is DocumentSnapshot<FirestoreDataMap>) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => ExploreSpotSummary.fromFirestore(doc.id, doc.data()))
          .toList();

      return ExploreFeedPage(
        items: items,
        hasMore: snapshot.docs.length >= limit,
        nextCursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ExploreFeedRepository] fetchPage failed (${e.code}): ${e.message}',
        );
      }
      throw ExploreFeedException(
        ExploreFeedErrorMapper.map(e),
        code: e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ExploreFeedRepository] fetchPage unexpected error: $e');
      }
      throw const ExploreFeedException(
        'Không thể tải bảng tin lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<ExploreSpotSummary?> fetchSpotById(String spotId) async {
    final cleanId = spotId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final doc = await _db.collection('spots').doc(cleanId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return ExploreSpotSummary.fromFirestore(doc.id, data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ExploreFeedRepository] fetchSpotById($cleanId) skipped: $e',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<ExploreUserHit>> searchUsersByHandle(String rawHandle) async {
    final cleanHandle = ExploreFeedLogic.extractHandle(
      rawHandle.startsWith('@') ? rawHandle : '@$rawHandle',
    );
    if (cleanHandle.isEmpty) return const [];

    try {
      final snap = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: cleanHandle)
          .where('username', isLessThanOrEqualTo: '$cleanHandle\uf8ff')
          .limit(6)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final username = ((data['username'] as String?) ?? '').trim();
        final displayName = ((data['displayName'] as String?) ?? '').trim();
        return ExploreUserHit(
          uid: doc.id,
          displayName: displayName.isNotEmpty ? displayName : username,
          username: username,
          avatarUrl: ((data['avatarUrl'] as String?) ?? '').trim(),
        );
      }).where((u) => u.username.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ExploreFeedRepository] searchUsersByHandle skipped: $e');
      }
      return const [];
    }
  }
}