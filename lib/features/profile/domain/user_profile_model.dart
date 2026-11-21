import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  const UserProfileModel({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    this.spotsCount = 0,
    this.totalLikes = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  final String uid;
  final String displayName;
  final String username;
  final String email;
  final String avatarUrl;
  final String bio;
  final int spotsCount;
  final int totalLikes;
  final int followersCount;
  final int followingCount;

  String get handle => username.isNotEmpty ? '@$username' : '';

  static String normalizeUsername(String input) {
    final stripped = input.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
    return stripped.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
  }

  static bool isValidUsername(String username) {
    return RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(username);
  }

  factory UserProfileModel.fromMap(String uid, Map<String, dynamic> data) {
    final email = (data['email'] as String?)?.trim() ?? '';
    final rawUsername = (data['username'] as String?)?.trim().toLowerCase() ?? '';
    final fallbackUsername = email.isNotEmpty
        ? normalizeUsername(email.split('@').first)
        : normalizeUsername(uid.substring(0, uid.length >= 8 ? 8 : uid.length));
    final resolvedUsername =
        rawUsername.isNotEmpty ? rawUsername : fallbackUsername;
    final rawName = (data['displayName'] as String?)?.trim() ?? '';

    return UserProfileModel(
      uid: uid,
      displayName: rawName.isNotEmpty
          ? rawName
          : (resolvedUsername.isNotEmpty ? resolvedUsername : 'Thành viên SpotShare'),
      username: resolvedUsername,
      email: email,
      avatarUrl: (data['avatarUrl'] as String?)?.trim() ?? '',
      bio: (data['bio'] as String?)?.trim() ?? '',
      spotsCount: (data['spotsCount'] as num?)?.toInt() ?? 0,
      totalLikes: (data['totalLikes'] as num?)?.toInt() ?? 0,
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return UserProfileModel.fromMap(doc.id, data);
  }
}