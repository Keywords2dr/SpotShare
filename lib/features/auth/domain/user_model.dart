import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl = '',
    this.bio = '',
    this.spotsCount = 0,
    this.totalLikes = 0,
    this.fcmToken = '',
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String avatarUrl;
  final String bio;
  final int spotsCount;
  final int totalLikes;
  final String fcmToken;
  final DateTime? createdAt;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map ? raw : const {};
    return UserModel(
      uid: (data['uid'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      spotsCount: (data['spotsCount'] as num?)?.toInt() ?? 0,
      totalLikes: (data['totalLikes'] as num?)?.toInt() ?? 0,
      fcmToken: (data['fcmToken'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'spotsCount': spotsCount,
      'totalLikes': totalLikes,
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}