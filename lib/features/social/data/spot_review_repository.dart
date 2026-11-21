import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef ReviewDataMap = Map<String, dynamic>;
typedef ReviewItemList = List<SpotReviewItem>;
typedef ReviewTreeNodeList = List<SpotReviewTreeNode>;
typedef ReviewDisplayRowList = List<SpotReviewDisplayRow>;

class SpotReviewException implements Exception {
  const SpotReviewException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class SpotReviewItem {
  const SpotReviewItem({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    this.photoUrls = const [],
    this.parentId,
    this.replyToReviewId,
    this.replyToUserId,
    this.replyToUserName,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String spotId;
  final String userId;
  final String userName;
  final String userAvatar;
  final int rating;
  final String comment;
  final List<String> photoUrls;
  final String? parentId;
  final String? replyToReviewId;
  final String? replyToUserId;
  final String? replyToUserName;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReply => parentId != null && parentId!.trim().isNotEmpty;
  String get threadRootId => isReply ? parentId!.trim() : id;

  SpotReviewItem copyWith({
    String? userName,
    String? userAvatar,
    int? rating,
    String? comment,
    List<String>? photoUrls,
    String? parentId,
    String? replyToReviewId,
    String? replyToUserId,
    String? replyToUserName,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpotReviewItem(
      id: id,
      spotId: spotId,
      userId: userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      photoUrls: photoUrls ?? this.photoUrls,
      parentId: parentId ?? this.parentId,
      replyToReviewId: replyToReviewId ?? this.replyToReviewId,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      replyToUserName: replyToUserName ?? this.replyToUserName,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SpotReviewItem.fromFirestore(
    String id,
    String spotId,
    ReviewDataMap data,
  ) {
    final rawRating = data['rating'];
    final parsedRating = rawRating is num ? rawRating.toInt() : 0;
    final rawParentId = (data['parentId'] as String?)?.trim();
    final rawReplyToReviewId = (data['replyToReviewId'] as String?)?.trim();
    final rawReplyToUid = (data['replyToUserId'] as String?)?.trim();
    final rawReplyToName = (data['replyToUserName'] as String?)?.trim();

    final rawName =
        ((data['userName'] as String?) ?? (data['authorName'] as String?) ?? '')
            .trim();
    final rawAvatar = ((data['userAvatar'] as String?) ??
            (data['authorAvatar'] as String?) ??
            '')
        .trim();
    final rawComment =
        ((data['comment'] as String?) ?? (data['content'] as String?) ?? '')
            .trim();

    final rawPhotos = data['photoUrls'];
    final photos = <String>[];
    if (rawPhotos is List) {
      for (final entry in rawPhotos) {
        if (entry is String && entry.trim().isNotEmpty) {
          photos.add(entry.trim());
        }
      }
    }

    return SpotReviewItem(
      id: id,
      spotId: spotId,
      userId: ((data['userId'] as String?) ?? '').trim(),
      userName: rawName.isNotEmpty ? rawName : 'Thành viên SpotShare',
      userAvatar: rawAvatar,
      rating: parsedRating < 0 ? 0 : (parsedRating > 5 ? 5 : parsedRating),
      comment: rawComment,
      photoUrls: photos,
      parentId: (rawParentId != null && rawParentId.isNotEmpty)
          ? rawParentId
          : null,
      replyToReviewId:
          (rawReplyToReviewId != null && rawReplyToReviewId.isNotEmpty)
              ? rawReplyToReviewId
              : null,
      replyToUserId: (rawReplyToUid != null && rawReplyToUid.isNotEmpty)
          ? rawReplyToUid
          : null,
      replyToUserName: (rawReplyToName != null && rawReplyToName.isNotEmpty)
          ? rawReplyToName
          : null,
      isEdited: data['isEdited'] == true,
      isDeleted: data['isDeleted'] == true,
      createdAt: SpotReviewLogic.parseDateTime(data['createdAt']),
      updatedAt: SpotReviewLogic.parseDateTime(data['updatedAt']),
    );
  }
}

class SpotReviewTreeNode {
  const SpotReviewTreeNode({
    required this.item,
    required this.depth,
    this.children = const [],
  });

  final SpotReviewItem item;
  final int depth;
  final ReviewTreeNodeList children;

  int get totalDescendantCount {
    var total = 0;
    for (final child in children) {
      total += 1 + child.totalDescendantCount;
    }
    return total;
  }
}

class SpotReviewDisplayRow {
  const SpotReviewDisplayRow({
    required this.item,
    required this.depth,
    required this.ancestorSpines,
    required this.hasNextSibling,
    required this.hasVisibleChildren,
  });

  final SpotReviewItem item;
  final int depth;
  final List<bool> ancestorSpines;
  final bool hasNextSibling;
  final bool hasVisibleChildren;
}

class SpotReviewThreadView {
  const SpotReviewThreadView({
    required this.rootNode,
    required this.visibleRows,
    required this.hiddenReplyCount,
  });

  final SpotReviewTreeNode rootNode;
  final ReviewDisplayRowList visibleRows;
  final int hiddenReplyCount;
}

class SpotRatingSummary {
  const SpotRatingSummary({
    required this.ratingAvg,
    required this.ratingCount,
  });

  final double ratingAvg;
  final int ratingCount;
}

class SpotReviewErrorMapper {
  static String map(
    Object error, {
    String fallback = 'Không thể xử lý bình luận lúc này. Vui lòng thử lại.',
  }) {
    if (error is SpotReviewException) {
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
        return 'Bạn không có quyền thực hiện thao tác này với bình luận.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'not-found':
        return 'Bình luận hoặc bài viết không còn tồn tại.';
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

class SpotReviewLogic {
  static const int maxCommentLength = 500;
  static const int maxVisualDepth = 2;

  static String? validateComment(String? rawComment) {
    final clean = (rawComment ?? '').trim();
    if (clean.isEmpty) {
      return 'Vui lòng nhập nội dung bình luận';
    }
    if (clean.length > maxCommentLength) {
      return 'Bình luận tối đa $maxCommentLength ký tự';
    }
    return null;
  }

  static int clampRating(int rating) {
    if (rating < 1) return 1;
    if (rating > 5) return 5;
    return rating;
  }

  static ReviewTreeNodeList buildTreeNodes(ReviewItemList allItems) {
    final roots = <SpotReviewItem>[];
    final repliesByRoot = <String, ReviewItemList>{};

    for (final item in allItems) {
      if (item.isReply) {
        final rootId = item.parentId!.trim();
        repliesByRoot.putIfAbsent(rootId, () => <SpotReviewItem>[]).add(item);
      } else {
        roots.add(item);
      }
    }

    roots.sort((a, b) => _compareDateDesc(a.createdAt, b.createdAt));

    final result = <SpotReviewTreeNode>[];
    final attachedRootIds = <String>{};

    for (final root in roots) {
      attachedRootIds.add(root.id);
      final depth1Nodes = _buildBranchChildren(
        root: root,
        rawReplies: repliesByRoot[root.id] ?? const [],
      );
      if (root.isDeleted && depth1Nodes.isEmpty) {
        continue;
      }
      result.add(
        SpotReviewTreeNode(
          item: root,
          depth: 0,
          children: depth1Nodes,
        ),
      );
    }

    for (final entry in repliesByRoot.entries) {
      if (attachedRootIds.contains(entry.key) || entry.value.isEmpty) {
        continue;
      }
      final orphanReplies = entry.value.where((r) => !r.isDeleted).toList()
        ..sort((a, b) => _compareDateAsc(a.createdAt, b.createdAt));
      for (final orphan in orphanReplies) {
        result.add(SpotReviewTreeNode(item: orphan, depth: 0));
      }
    }

    return result;
  }

  static ReviewTreeNodeList _buildBranchChildren({
    required SpotReviewItem root,
    required ReviewItemList rawReplies,
  }) {
    if (rawReplies.isEmpty) return const [];

    final chronological = List<SpotReviewItem>.from(rawReplies)
      ..sort((a, b) => _compareDateAsc(a.createdAt, b.createdAt));

    final depth1Order = <String>[];
    final itemById = <String, SpotReviewItem>{};
    final depth1AnchorById = <String, String>{};
    final depth2ByAnchor = <String, ReviewItemList>{};

    for (var i = 0; i < chronological.length; i++) {
      final reply = chronological[i];
      itemById[reply.id] = reply;

      String? targetId;
      final explicitTarget = reply.replyToReviewId?.trim() ?? '';
      if (explicitTarget.isNotEmpty &&
          explicitTarget != root.id &&
          explicitTarget != reply.id &&
          itemById.containsKey(explicitTarget)) {
        targetId = explicitTarget;
      } else if (explicitTarget.isEmpty) {
        final replyToUid = reply.replyToUserId?.trim() ?? '';
        if (replyToUid.isNotEmpty && replyToUid != root.userId) {
          for (var j = i - 1; j >= 0; j--) {
            if (chronological[j].userId == replyToUid) {
              targetId = chronological[j].id;
              break;
            }
          }
        }
      }

      if (targetId == null) {
        depth1Order.add(reply.id);
        depth1AnchorById[reply.id] = reply.id;
      } else {
        final anchorId = depth1AnchorById[targetId] ?? targetId;
        if (depth1AnchorById.containsKey(anchorId)) {
          depth1AnchorById[reply.id] = anchorId;
          depth2ByAnchor
              .putIfAbsent(anchorId, () => <SpotReviewItem>[])
              .add(reply);
        } else {
          depth1Order.add(reply.id);
          depth1AnchorById[reply.id] = reply.id;
        }
      }
    }

    final nodes = <SpotReviewTreeNode>[];
    for (final anchorId in depth1Order) {
      final anchorItem = itemById[anchorId];
      if (anchorItem == null) continue;

      final depth2Items = (depth2ByAnchor[anchorId] ?? const [])
          .where((item) => !item.isDeleted)
          .toList();

      if (anchorItem.isDeleted && depth2Items.isEmpty) {
        continue;
      }

      final depth2Nodes = depth2Items
          .map(
            (child) => SpotReviewTreeNode(
              item: child,
              depth: maxVisualDepth,
            ),
          )
          .toList();

      nodes.add(
        SpotReviewTreeNode(
          item: anchorItem,
          depth: 1,
          children: depth2Nodes,
        ),
      );
    }

    return nodes;
  }

  static SpotReviewThreadView buildThreadView({
    required SpotReviewTreeNode rootNode,
    required bool isExpanded,
    int collapsedReplyRowLimit = 3,
  }) {
    final totalReplies = rootNode.totalDescendantCount;
    final hasLimit = !isExpanded && totalReplies > collapsedReplyRowLimit;

    final selectedDepth1 = <SpotReviewTreeNode>[];
    var usedReplySlots = 0;

    for (final depth1 in rootNode.children) {
      if (hasLimit && usedReplySlots >= collapsedReplyRowLimit) {
        break;
      }
      usedReplySlots++;

      final selectedDepth2 = <SpotReviewTreeNode>[];
      for (final depth2 in depth1.children) {
        if (hasLimit && usedReplySlots >= collapsedReplyRowLimit) {
          break;
        }
        usedReplySlots++;
        selectedDepth2.add(depth2);
      }

      selectedDepth1.add(
        SpotReviewTreeNode(
          item: depth1.item,
          depth: 1,
          children: selectedDepth2,
        ),
      );
    }

    final hiddenCount = totalReplies - usedReplySlots;
    final hasToggleRowAfterReplies =
        totalReplies > collapsedReplyRowLimit;

    final rows = <SpotReviewDisplayRow>[
      SpotReviewDisplayRow(
        item: rootNode.item,
        depth: 0,
        ancestorSpines: const [],
        hasNextSibling: false,
        hasVisibleChildren: selectedDepth1.isNotEmpty || hasToggleRowAfterReplies,
      ),
    ];

    for (var i = 0; i < selectedDepth1.length; i++) {
      final depth1 = selectedDepth1[i];
      final isLastDepth1 = i == selectedDepth1.length - 1;
      final depth1HasNext = !isLastDepth1 || hasToggleRowAfterReplies;
      final depth2List = depth1.children;

      rows.add(
        SpotReviewDisplayRow(
          item: depth1.item,
          depth: 1,
          ancestorSpines: const [],
          hasNextSibling: depth1HasNext,
          hasVisibleChildren: depth2List.isNotEmpty,
        ),
      );

      for (var j = 0; j < depth2List.length; j++) {
        final depth2 = depth2List[j];
        final depth2HasNext = j < depth2List.length - 1;
        rows.add(
          SpotReviewDisplayRow(
            item: depth2.item,
            depth: 2,
            ancestorSpines: [depth1HasNext],
            hasNextSibling: depth2HasNext,
            hasVisibleChildren: false,
          ),
        );
      }
    }

    return SpotReviewThreadView(
      rootNode: rootNode,
      visibleRows: rows,
      hiddenReplyCount: hiddenCount < 0 ? 0 : hiddenCount,
    );
  }

  static bool hasActiveChildReplies({
    required SpotReviewItem target,
    required ReviewItemList threadItems,
  }) {
    if (!target.isReply) {
      return threadItems.any(
        (item) =>
            item.id != target.id &&
            item.parentId == target.id &&
            !item.isDeleted,
      );
    }

    final targetId = target.id;
    final targetTime = target.createdAt;
    for (final item in threadItems) {
      if (item.id == targetId || item.isDeleted || !item.isReply) {
        continue;
      }
      final explicit = item.replyToReviewId?.trim() ?? '';
      if (explicit == targetId) {
        return true;
      }
      if (explicit.isEmpty && item.replyToUserId == target.userId) {
        if (targetTime == null ||
            item.createdAt == null ||
            !item.createdAt!.isBefore(targetTime)) {
          return true;
        }
      }
    }
    return false;
  }

  static int countActiveComments(ReviewTreeNodeList trees) {
    var total = 0;
    void walk(SpotReviewTreeNode node) {
      if (!node.item.isDeleted) {
        total++;
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    for (final tree in trees) {
      walk(tree);
    }
    return total;
  }

  static SpotRatingSummary calculateRatingSummary(ReviewItemList allItems) {
    var count = 0;
    var sum = 0;
    for (final item in allItems) {
      if (item.isReply || item.isDeleted) continue;
      if (item.rating >= 1 && item.rating <= 5) {
        count++;
        sum += item.rating;
      }
    }
    if (count == 0) {
      return const SpotRatingSummary(ratingAvg: 0.0, ratingCount: 0);
    }
    final avg = double.parse((sum / count).toStringAsFixed(1));
    return SpotRatingSummary(ratingAvg: avg, ratingCount: count);
  }

  static int computeRuleSafeRatingCount({
    required int currentSpotRatingCount,
    required int delta,
  }) {
    final safeCurrent =
        currentSpotRatingCount < 0 ? 0 : currentSpotRatingCount;
    final clampedDelta = delta.clamp(-1, 1);
    final next = safeCurrent + clampedDelta;
    return next < 0 ? 0 : next;
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
    final yesterday = current.subtract(const Duration(days: 1));
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return 'Hôm qua $hh:$mm';
    }
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mo = dateTime.month.toString().padLeft(2, '0');
    return '$dd/$mo/${dateTime.year}';
  }

  static DateTime? parseDateTime(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static int _compareDateDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return b.compareTo(a);
  }

  static int _compareDateAsc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

abstract class SpotReviewGateway {
  Stream<ReviewItemList> watchReviews(String spotId);

  Future<void> addReview({
    required String spotId,
    required String userId,
    required String comment,
    required int rating,
    SpotReviewItem? replyTo,
  });

  Future<void> updateReview({
    required SpotReviewItem target,
    required String currentUserId,
    required String comment,
    int? rating,
  });

  Future<void> deleteReview({
    required SpotReviewItem target,
    required String currentUserId,
  });
}

class FirestoreSpotReviewRepository implements SpotReviewGateway {
  FirestoreSpotReviewRepository({
    this.firestore,
    this.firebaseAuth,
  });

  final FirebaseFirestore? firestore;
  final FirebaseAuth? firebaseAuth;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;

  String _resolveLiveUserId(String fallbackUserId) {
    try {
      final liveUid = _auth.currentUser?.uid.trim() ?? '';
      if (liveUid.isNotEmpty) {
        return liveUid;
      }
    } catch (_) {}
    return fallbackUserId.trim();
  }

  @override
  Stream<ReviewItemList> watchReviews(String spotId) {
    final cleanSpotId = spotId.trim();
    if (cleanSpotId.isEmpty) {
      return Stream<ReviewItemList>.value(const []);
    }
    return _db
        .collection('spots')
        .doc(cleanSpotId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => SpotReviewItem.fromFirestore(
                  doc.id,
                  cleanSpotId,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> addReview({
    required String spotId,
    required String userId,
    required String comment,
    required int rating,
    SpotReviewItem? replyTo,
  }) async {
    final cleanSpotId = spotId.trim();
    final cleanUserId = _resolveLiveUserId(userId);
    final cleanComment = comment.trim();

    if (cleanUserId.isEmpty) {
      throw const SpotReviewException(
        'Vui lòng đăng nhập để gửi bình luận.',
        code: 'unauthenticated',
      );
    }
    if (cleanSpotId.isEmpty) {
      throw const SpotReviewException(
        'Không xác định được bài viết cần bình luận.',
        code: 'invalid-argument',
      );
    }
    final validationError = SpotReviewLogic.validateComment(cleanComment);
    if (validationError != null) {
      throw SpotReviewException(validationError, code: 'invalid-argument');
    }

    final isReply = replyTo != null;
    final resolvedRating = isReply ? 0 : SpotReviewLogic.clampRating(rating);
    final parentId = isReply ? replyTo.threadRootId : null;
    final replyToReviewId = isReply ? replyTo.id : null;
    final replyToUserId = isReply ? replyTo.userId : null;
    final replyToUserName = isReply ? replyTo.userName : null;

    try {
      final profile = await _resolveAuthorProfile(cleanUserId);
      final reviewsCol =
          _db.collection('spots').doc(cleanSpotId).collection('reviews');

      await reviewsCol.add({
        'userId': cleanUserId,
        'userName': profile.displayName,
        'userAvatar': profile.avatarUrl,
        'rating': resolvedRating,
        'comment': cleanComment,
        'photoUrls': const <String>[],
        'parentId': parentId,
        'replyToReviewId': replyToReviewId,
        'replyToUserId': replyToUserId,
        'replyToUserName': replyToUserName,
        'isEdited': false,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });

      if (!isReply) {
        await _syncSpotRating(spotId: cleanSpotId, countDelta: 1);
      }
    } on SpotReviewException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotReviewRepository] addReview failed (${e.code}): ${e.message}',
        );
      }
      throw SpotReviewException(SpotReviewErrorMapper.map(e), code: e.code);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotReviewRepository] addReview unexpected error: $e');
      }
      throw const SpotReviewException(
        'Không thể gửi bình luận lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> updateReview({
    required SpotReviewItem target,
    required String currentUserId,
    required String comment,
    int? rating,
  }) async {
    final cleanUid = _resolveLiveUserId(currentUserId);
    final cleanComment = comment.trim();

    if (cleanUid.isEmpty) {
      throw const SpotReviewException(
        'Vui lòng đăng nhập để chỉnh sửa bình luận.',
        code: 'unauthenticated',
      );
    }
    if (cleanUid != target.userId) {
      throw const SpotReviewException(
        'Bạn chỉ có thể chỉnh sửa bình luận của chính mình.',
        code: 'permission-denied',
      );
    }
    if (target.isDeleted) {
      throw const SpotReviewException(
        'Không thể chỉnh sửa bình luận đã bị xóa.',
        code: 'failed-precondition',
      );
    }

    final validationError = SpotReviewLogic.validateComment(cleanComment);
    if (validationError != null) {
      throw SpotReviewException(validationError, code: 'invalid-argument');
    }

    final nextRating = target.isReply
        ? 0
        : SpotReviewLogic.clampRating(rating ?? target.rating);
    final ratingChanged = !target.isReply && nextRating != target.rating;

    try {
      final reviewRef = _db
          .collection('spots')
          .doc(target.spotId)
          .collection('reviews')
          .doc(target.id);

      await reviewRef.update({
        'comment': cleanComment,
        'rating': nextRating,
        'isEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (ratingChanged) {
        await _syncSpotRating(spotId: target.spotId, countDelta: 0);
      }
    } on SpotReviewException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotReviewRepository] updateReview failed (${e.code}): ${e.message}',
        );
      }
      throw SpotReviewException(SpotReviewErrorMapper.map(e), code: e.code);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotReviewRepository] updateReview unexpected error: $e');
      }
      throw const SpotReviewException(
        'Không thể cập nhật bình luận lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> deleteReview({
    required SpotReviewItem target,
    required String currentUserId,
  }) async {
    final cleanUid = _resolveLiveUserId(currentUserId);
    if (cleanUid.isEmpty) {
      throw const SpotReviewException(
        'Vui lòng đăng nhập để xóa bình luận.',
        code: 'unauthenticated',
      );
    }
    if (cleanUid != target.userId) {
      throw const SpotReviewException(
        'Bạn chỉ có thể xóa bình luận của chính mình.',
        code: 'permission-denied',
      );
    }

    try {
      final reviewsCol =
          _db.collection('spots').doc(target.spotId).collection('reviews');
      final reviewRef = reviewsCol.doc(target.id);

      final threadSnap = await reviewsCol
          .where('parentId', isEqualTo: target.threadRootId)
          .get();
      final threadItems = threadSnap.docs
          .map(
            (doc) => SpotReviewItem.fromFirestore(
              doc.id,
              target.spotId,
              doc.data(),
            ),
          )
          .toList();

      final hasChildren = SpotReviewLogic.hasActiveChildReplies(
        target: target,
        threadItems: threadItems,
      );

      if (hasChildren) {
        await reviewRef.update({
          'isDeleted': true,
          'comment': '',
          'rating': 0,
          'photoUrls': const <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await reviewRef.delete();
      }

      if (!target.isReply && !target.isDeleted) {
        await _syncSpotRating(spotId: target.spotId, countDelta: -1);
      }
    } on SpotReviewException {
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotReviewRepository] deleteReview failed (${e.code}): ${e.message}',
        );
      }
      throw SpotReviewException(SpotReviewErrorMapper.map(e), code: e.code);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotReviewRepository] deleteReview unexpected error: $e');
      }
      throw const SpotReviewException(
        'Không thể xóa bình luận lúc này. Vui lòng thử lại.',
        code: 'unknown',
      );
    }
  }

  Future<({String displayName, String avatarUrl})> _resolveAuthorProfile(
    String userId,
  ) async {
    final currentUser = _auth.currentUser;
    String name = (currentUser?.displayName ?? '').trim();
    String avatar = (currentUser?.photoURL ?? '').trim();

    try {
      final userSnap = await _db.collection('users').doc(userId).get();
      final data = userSnap.data();
      if (data != null) {
        final docName = ((data['displayName'] as String?) ?? '').trim();
        final docAvatar = ((data['avatarUrl'] as String?) ?? '').trim();
        if (docName.isNotEmpty) name = docName;
        if (docAvatar.isNotEmpty) avatar = docAvatar;
      }
    } catch (_) {}

    if (name.isEmpty) {
      final email = (currentUser?.email ?? '').trim();
      name = email.contains('@')
          ? email.split('@').first
          : 'Thành viên SpotShare';
    }

    return (displayName: name, avatarUrl: avatar);
  }

  Future<void> _syncSpotRating({
    required String spotId,
    required int countDelta,
  }) async {
    try {
      final spotRef = _db.collection('spots').doc(spotId);
      final reviewsSnap = await spotRef.collection('reviews').get();
      final items = reviewsSnap.docs
          .map((doc) => SpotReviewItem.fromFirestore(doc.id, spotId, doc.data()))
          .toList();
      final summary = SpotReviewLogic.calculateRatingSummary(items);

      await _db.runTransaction<void>((transaction) async {
        final spotSnap = await transaction.get(spotRef);
        if (!spotSnap.exists) return;

        final spotData = spotSnap.data() ?? <String, dynamic>{};
        final rawCount = spotData['ratingCount'];
        final currentCount = rawCount is num ? rawCount.toInt() : 0;

        final nextCount = SpotReviewLogic.computeRuleSafeRatingCount(
          currentSpotRatingCount: currentCount,
          delta: countDelta,
        );
        final nextAvg = nextCount == 0 ? 0.0 : summary.ratingAvg;

        transaction.update(spotRef, {
          'ratingCount': nextCount,
          'ratingAvg': nextAvg,
        });
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotReviewRepository] non-fatal rating sync skipped: $e');
      }
    }
  }
}