import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef NotificationDataMap = Map<String, dynamic>;
typedef NotificationList = List<NotificationItem>;

enum NotificationType { like, follow, comment, reply }

enum NotificationFilter { all, unread, likes, comments, follows }

extension NotificationTypeX on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.like:
        return 'like';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.reply:
        return 'reply';
    }
  }

  static NotificationType fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'follow':
        return NotificationType.follow;
      case 'comment':
        return NotificationType.comment;
      case 'reply':
        return NotificationType.reply;
      case 'like':
      default:
        return NotificationType.like;
    }
  }
}

class NotificationsException implements Exception {
  const NotificationsException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.actorName,
    this.actorAvatar = '',
    required this.type,
    this.spotId = '',
    this.spotTitle = '',
    this.spotThumbnail = '',
    this.reviewId = '',
    this.commentPreview = '',
    this.isRead = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String actorName;
  final String actorAvatar;
  final NotificationType type;
  final String spotId;
  final String spotTitle;
  final String spotThumbnail;
  final String reviewId;
  final String commentPreview;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DateTime? get effectiveTime => updatedAt ?? createdAt;

  bool get hasSpotTarget => spotId.isNotEmpty;

  String get actionDescription {
    switch (type) {
      case NotificationType.like:
        return spotTitle.isNotEmpty
            ? 'đã thích bài viết "$spotTitle"'
            : 'đã thích bài viết của bạn';
      case NotificationType.follow:
        return 'đã bắt đầu theo dõi bạn';
      case NotificationType.comment:
        return spotTitle.isNotEmpty
            ? 'đã bình luận về "$spotTitle"'
            : 'đã bình luận bài viết của bạn';
      case NotificationType.reply:
        return spotTitle.isNotEmpty
            ? 'đã trả lời bình luận của bạn tại "$spotTitle"'
            : 'đã trả lời bình luận của bạn';
    }
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? updatedAt,
  }) {
    return NotificationItem(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      actorName: actorName,
      actorAvatar: actorAvatar,
      type: type,
      spotId: spotId,
      spotTitle: spotTitle,
      spotThumbnail: spotThumbnail,
      reviewId: reviewId,
      commentPreview: commentPreview,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NotificationItem.fromFirestore(
    String id,
    NotificationDataMap data,
  ) {
    final rawName = ((data['actorName'] as String?) ?? '').trim();
    return NotificationItem(
      id: id,
      recipientId: ((data['recipientId'] as String?) ?? '').trim(),
      actorId: ((data['actorId'] as String?) ?? '').trim(),
      actorName: rawName.isNotEmpty ? rawName : 'Thành viên SpotShare',
      actorAvatar: ((data['actorAvatar'] as String?) ?? '').trim(),
      type: NotificationTypeX.fromValue(data['type'] as String?),
      spotId: ((data['spotId'] as String?) ?? '').trim(),
      spotTitle: ((data['spotTitle'] as String?) ?? '').trim(),
      spotThumbnail: ((data['spotThumbnail'] as String?) ?? '').trim(),
      reviewId: ((data['reviewId'] as String?) ?? '').trim(),
      commentPreview: ((data['commentPreview'] as String?) ?? '').trim(),
      isRead: data['isRead'] == true,
      createdAt: NotificationsLogic.parseTimestamp(data['createdAt']),
      updatedAt: NotificationsLogic.parseTimestamp(data['updatedAt']),
    );
  }
}

class NotificationsErrorMapper {
  static String map(
    Object error, {
    String fallback = 'Không thể tải hộp thư thông báo lúc này. Vui lòng thử lại.',
  }) {
    if (error is NotificationsException) {
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
        return 'Bạn chưa có quyền truy cập hộp thư thông báo. Vui lòng kiểm tra phiên đăng nhập hoặc quy tắc bảo mật Firestore.';
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

class NotificationsLogic {
  static bool shouldNotify({
    required String recipientId,
    required String actorId,
  }) {
    final cleanRecipient = recipientId.trim();
    final cleanActor = actorId.trim();
    if (cleanRecipient.isEmpty || cleanActor.isEmpty) return false;
    return cleanRecipient != cleanActor;
  }

  static String? deterministicId({
    required NotificationType type,
    required String actorId,
    String spotId = '',
  }) {
    final cleanActor = actorId.trim();
    final cleanSpot = spotId.trim();
    if (cleanActor.isEmpty) return null;

    switch (type) {
      case NotificationType.like:
        if (cleanSpot.isEmpty) return null;
        return 'like_${cleanSpot}_$cleanActor';
      case NotificationType.follow:
        return 'follow_$cleanActor';
      case NotificationType.comment:
      case NotificationType.reply:
        return null;
    }
  }

  static String truncatePreview(String raw, {int maxLength = 90}) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1).trimRight()}…';
  }

  static NotificationList sortByNewest(NotificationList items) {
    final sorted = List<NotificationItem>.from(items);
    sorted.sort((a, b) {
      final aTime = a.effectiveTime;
      final bTime = b.effectiveTime;
      if (aTime == null && bTime == null) return b.id.compareTo(a.id);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  static int countUnread(NotificationList items) {
    var count = 0;
    for (final item in items) {
      if (!item.isRead) count++;
    }
    return count;
  }

  static NotificationList filterItems(
    NotificationList items,
    NotificationFilter filter,
  ) {
    switch (filter) {
      case NotificationFilter.all:
        return items;
      case NotificationFilter.unread:
        return items.where((item) => !item.isRead).toList();
      case NotificationFilter.likes:
        return items
            .where((item) => item.type == NotificationType.like)
            .toList();
      case NotificationFilter.comments:
        return items
            .where(
              (item) =>
                  item.type == NotificationType.comment ||
                  item.type == NotificationType.reply,
            )
            .toList();
      case NotificationFilter.follows:
        return items
            .where((item) => item.type == NotificationType.follow)
            .toList();
    }
  }

  static String formatRelativeTime(DateTime? time, {DateTime? now}) {
    if (time == null) return 'Vừa xong';
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year}';
  }

  static DateTime? parseTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

abstract class NotificationsGateway {
  Stream<NotificationList> watchNotifications({
    required String userId,
    int limit = 60,
  });

  Future<void> sendNotification({
    required String recipientId,
    required String actorId,
    String actorName = '',
    String actorAvatar = '',
    required NotificationType type,
    String spotId = '',
    String spotTitle = '',
    String spotThumbnail = '',
    String reviewId = '',
    String commentPreview = '',
  });

  Future<void> removeInteractionNotification({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    String spotId = '',
  });

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  });

  Future<void> markAllAsRead({
    required String userId,
    required List<String> unreadNotificationIds,
  });

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  });
}

class FirestoreNotificationsRepository implements NotificationsGateway {
  FirestoreNotificationsRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  CollectionReference<NotificationDataMap> _notificationsRef(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  @override
  Stream<NotificationList> watchNotifications({
    required String userId,
    int limit = 60,
  }) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) {
      return Stream<NotificationList>.value(const []);
    }

    return _notificationsRef(cleanUid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => NotificationsLogic.sortByNewest(
            snap.docs
                .map((doc) => NotificationItem.fromFirestore(doc.id, doc.data()))
                .toList(),
          ),
        );
  }

  @override
  Future<void> sendNotification({
    required String recipientId,
    required String actorId,
    String actorName = '',
    String actorAvatar = '',
    required NotificationType type,
    String spotId = '',
    String spotTitle = '',
    String spotThumbnail = '',
    String reviewId = '',
    String commentPreview = '',
  }) async {
    final cleanRecipient = recipientId.trim();
    final cleanActor = actorId.trim();
    if (!NotificationsLogic.shouldNotify(
      recipientId: cleanRecipient,
      actorId: cleanActor,
    )) {
      return;
    }

    var resolvedActorName = actorName.trim();
    var resolvedActorAvatar = actorAvatar.trim();
    if (resolvedActorName.isEmpty || resolvedActorAvatar.isEmpty) {
      try {
        final actorSnap = await _db.collection('users').doc(cleanActor).get();
        final actorData = actorSnap.data();
        if (actorData != null) {
          if (resolvedActorName.isEmpty) {
            final name = ((actorData['displayName'] as String?) ?? '').trim();
            final username = ((actorData['username'] as String?) ?? '').trim();
            resolvedActorName = name.isNotEmpty
                ? name
                : (username.isNotEmpty ? '@$username' : '');
          }
          if (resolvedActorAvatar.isEmpty) {
            resolvedActorAvatar =
                ((actorData['avatarUrl'] as String?) ?? '').trim();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NotificationsRepository] actor lookup skipped: $e');
        }
      }
    }
    if (resolvedActorName.isEmpty) {
      resolvedActorName = 'Thành viên SpotShare';
    }

    final cleanSpotId = spotId.trim();
    var resolvedSpotTitle = spotTitle.trim();
    var resolvedSpotThumb = spotThumbnail.trim();
    if (cleanSpotId.isNotEmpty &&
        (resolvedSpotTitle.isEmpty || resolvedSpotThumb.isEmpty)) {
      try {
        final spotSnap = await _db.collection('spots').doc(cleanSpotId).get();
        final spotData = spotSnap.data();
        if (spotData != null) {
          if (resolvedSpotTitle.isEmpty) {
            resolvedSpotTitle = ((spotData['title'] as String?) ?? '').trim();
          }
          if (resolvedSpotThumb.isEmpty) {
            final rawImages = spotData['imageUrls'];
            if (rawImages is List) {
              for (final entry in rawImages) {
                if (entry is String && entry.trim().isNotEmpty) {
                  resolvedSpotThumb = entry.trim();
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NotificationsRepository] spot lookup skipped: $e');
        }
      }
    }

    final docId = NotificationsLogic.deterministicId(
      type: type,
      actorId: cleanActor,
      spotId: cleanSpotId,
    );
    final ref = docId != null
        ? _notificationsRef(cleanRecipient).doc(docId)
        : _notificationsRef(cleanRecipient).doc();

    final payload = <String, dynamic>{
      'recipientId': cleanRecipient,
      'actorId': cleanActor,
      'actorName': resolvedActorName,
      'actorAvatar': resolvedActorAvatar,
      'type': type.value,
      'spotId': cleanSpotId,
      'spotTitle': resolvedSpotTitle,
      'spotThumbnail': resolvedSpotThumb,
      'reviewId': reviewId.trim(),
      'commentPreview': NotificationsLogic.truncatePreview(commentPreview),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.set(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationsRepository] sendNotification skipped: $e');
      }
    }
  }

  @override
  Future<void> removeInteractionNotification({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    String spotId = '',
  }) async {
    final cleanRecipient = recipientId.trim();
    final cleanActor = actorId.trim();
    if (!NotificationsLogic.shouldNotify(
      recipientId: cleanRecipient,
      actorId: cleanActor,
    )) {
      return;
    }

    final docId = NotificationsLogic.deterministicId(
      type: type,
      actorId: cleanActor,
      spotId: spotId,
    );
    if (docId == null) return;

    try {
      await _notificationsRef(cleanRecipient).doc(docId).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationsRepository] removeInteractionNotification skipped: $e',
        );
      }
    }
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final cleanUid = userId.trim();
    final cleanNotifId = notificationId.trim();
    if (cleanUid.isEmpty || cleanNotifId.isEmpty) return;

    try {
      await _notificationsRef(cleanUid).doc(cleanNotifId).update({
        'isRead': true,
      });
    } on FirebaseException catch (e) {
      throw NotificationsException(
        NotificationsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const NotificationsException(
        'Không thể cập nhật trạng thái đã đọc lúc này.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> markAllAsRead({
    required String userId,
    required List<String> unreadNotificationIds,
  }) async {
    final cleanUid = userId.trim();
    final ids = unreadNotificationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanUid.isEmpty || ids.isEmpty) return;

    try {
      const batchLimit = 400;
      final colRef = _notificationsRef(cleanUid);
      for (var i = 0; i < ids.length; i += batchLimit) {
        final end = (i + batchLimit < ids.length) ? i + batchLimit : ids.length;
        final batch = _db.batch();
        for (var j = i; j < end; j++) {
          batch.update(colRef.doc(ids[j]), {'isRead': true});
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw NotificationsException(
        NotificationsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const NotificationsException(
        'Không thể đánh dấu tất cả đã đọc lúc này.',
        code: 'unknown',
      );
    }
  }

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    final cleanUid = userId.trim();
    final cleanNotifId = notificationId.trim();
    if (cleanUid.isEmpty || cleanNotifId.isEmpty) return;

    try {
      await _notificationsRef(cleanUid).doc(cleanNotifId).delete();
    } on FirebaseException catch (e) {
      throw NotificationsException(
        NotificationsErrorMapper.map(e),
        code: e.code,
      );
    } catch (_) {
      throw const NotificationsException(
        'Không thể xóa thông báo lúc này.',
        code: 'unknown',
      );
    }
  }
}