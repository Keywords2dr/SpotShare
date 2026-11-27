import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ProfileDataMap = Map<String, dynamic>;

enum ProfileAvatarSourceOption { gallery, camera }

class ProfileSummaryData {
  const ProfileSummaryData({
    required this.displayName,
    required this.email,
    required this.username,
    required this.handle,
    required this.avatarUrl,
    required this.bio,
    required this.spotsCount,
    required this.followingCount,
    required this.followersCount,
    required this.totalLikes,
  });

  final String displayName;
  final String email;
  final String username;
  final String handle;
  final String avatarUrl;
  final String bio;
  final int spotsCount;
  final int followingCount;
  final int followersCount;
  final int totalLikes;
}

class ProfileDataParser {
  static ProfileSummaryData parse({
    required ProfileDataMap data,
    required String uid,
    String? authDisplayName,
    String? authEmail,
    String? authPhotoUrl,
    int? liveSpotsCount,
    String Function(String raw)? normalizeUsername,
    String Function(String rawUrl)? formatAvatarUrl,
  }) {
    final cleanUid = uid.trim();
    final email = _firstNonEmpty([
      data['email'] as String?,
      authEmail,
    ]);

    final emailPrefix = email.contains('@') ? email.split('@').first.trim() : '';
    final displayName = _firstNonEmpty([
      data['displayName'] as String?,
      authDisplayName,
      emailPrefix,
      'Thành viên SpotShare',
    ]);

    final savedUsername =
        ((data['username'] as String?) ?? '').trim().toLowerCase();
    final fallbackSource = emailPrefix.isNotEmpty
        ? emailPrefix
        : (cleanUid.length >= 8 ? cleanUid.substring(0, 8) : cleanUid);
    final normalizer = normalizeUsername ?? _defaultNormalizeUsername;
    final normalizedFallback = normalizer(fallbackSource).trim().toLowerCase();
    final username = savedUsername.isNotEmpty
        ? savedUsername
        : (normalizedFallback.isNotEmpty ? normalizedFallback : 'spotshare');

    final rawAvatar = _firstNonEmpty([
      data['avatarUrl'] as String?,
      authPhotoUrl,
    ]);
    final avatarUrl = rawAvatar.isEmpty
        ? ''
        : (formatAvatarUrl != null ? formatAvatarUrl(rawAvatar) : rawAvatar);

    final bio = ((data['bio'] as String?) ?? '').trim();
    final docSpotsCount = parseNonNegativeInt(data['spotsCount']);
    final resolvedSpotsCount = liveSpotsCount != null
        ? (liveSpotsCount < 0 ? 0 : liveSpotsCount)
        : docSpotsCount;

    return ProfileSummaryData(
      displayName: displayName,
      email: email,
      username: username,
      handle: '@$username',
      avatarUrl: avatarUrl,
      bio: bio,
      spotsCount: resolvedSpotsCount,
      followingCount: parseNonNegativeInt(data['followingCount']),
      followersCount: parseNonNegativeInt(data['followersCount']),
      totalLikes: parseNonNegativeInt(data['totalLikes']),
    );
  }

  static int parseNonNegativeInt(Object? raw) {
    if (raw is int) {
      return raw < 0 ? 0 : raw;
    }
    if (raw is num) {
      final value = raw.toInt();
      return value < 0 ? 0 : value;
    }
    return 0;
  }

  static String formatCompactCount(int rawCount) {
    final count = rawCount < 0 ? 0 : rawCount;
    if (count < 1000) {
      return '$count';
    }
    if (count < 1000000) {
      final whole = count ~/ 1000;
      final tenth = (count % 1000) ~/ 100;
      if (whole >= 100 || tenth == 0) {
        return '${whole}K';
      }
      return '$whole.${tenth}K';
    }
    final whole = count ~/ 1000000;
    final tenth = (count % 1000000) ~/ 100000;
    if (whole >= 100 || tenth == 0) {
      return '${whole}M';
    }
    return '$whole.${tenth}M';
  }

  static String avatarInitial(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'S';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final value = (candidate ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _defaultNormalizeUsername(String raw) {
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return cleaned.isEmpty ? 'spotshare' : cleaned;
  }
}

class ProfileErrorMapper {
  static String map(
    Object error, {
    required String fallback,
  }) {
    String? code;
    if (error is FirebaseException) {
      code = error.code;
    } else if (error is PlatformException) {
      code = error.code;
    }

    final raw = error.toString().toLowerCase();
    final resolvedCode = code ?? _extractCode(raw);

    switch (resolvedCode) {
      case 'permission-denied':
        return 'Bạn chưa có quyền truy cập hồ sơ này. Vui lòng kiểm tra phiên đăng nhập hoặc quy tắc bảo mật.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Mất kết nối mạng hoặc máy chủ phản hồi chậm. Vui lòng thử lại.';
      case 'photo_access_denied':
        return 'Ứng dụng chưa được cấp quyền truy cập Thư viện ảnh.';
      case 'camera_access_denied':
        return 'Ứng dụng chưa được cấp quyền truy cập Camera.';
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
    if (raw.contains('photo_access_denied')) return 'photo_access_denied';
    if (raw.contains('camera_access_denied')) return 'camera_access_denied';
    return null;
  }
}

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.profile,
    required this.isUploadingAvatar,
    required this.onCopyHandle,
    required this.onEditProfile,
    required this.onPickAvatar,
    this.errorMessage,
    this.onRetry,
  });

  final ProfileSummaryData profile;
  final bool isUploadingAvatar;
  final VoidCallback onCopyHandle;
  final VoidCallback onEditProfile;
  final VoidCallback onPickAvatar;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null) ...[
            Container(
              key: const Key('profile_error_banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      key: const Key('profile_retry_button'),
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onErrorContainer,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      key: const Key('profile_display_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      key: const Key('profile_copy_handle_button'),
                      onTap: onCopyHandle,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                profile.handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _ProfileStatItem(
                          key: const Key('profile_stat_spots'),
                          count: profile.spotsCount,
                          label: 'Bài đăng',
                        ),
                        _ProfileStatItem(
                          key: const Key('profile_stat_following'),
                          count: profile.followingCount,
                          label: 'Đã follow',
                        ),
                        _ProfileStatItem(
                          key: const Key('profile_stat_followers'),
                          count: profile.followersCount,
                          label: 'Follower',
                        ),
                        _ProfileStatItem(
                          key: const Key('profile_stat_likes'),
                          count: profile.totalLikes,
                          label: 'Thích',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Đổi ảnh đại diện',
                child: GestureDetector(
                  key: const Key('profile_avatar_button'),
                  onTap: isUploadingAvatar ? null : onPickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: colors.surfaceContainerHighest,
                        backgroundImage: profile.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(profile.avatarUrl)
                            : null,
                        onBackgroundImageError:
                            profile.avatarUrl.isNotEmpty ? (_, _) {} : null,
                        child: isUploadingAvatar
                            ? Container(
                                decoration: BoxDecoration(
                                  color: colors.scrim.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : (profile.avatarUrl.isEmpty
                                ? Text(
                                    ProfileDataParser.avatarInitial(
                                      profile.displayName,
                                    ),
                                    style:
                                        theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.bio.isEmpty)
            InkWell(
              key: const Key('profile_add_bio_button'),
              onTap: onEditProfile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Thêm tiểu sử',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                profile.bio,
                key: const Key('profile_bio_text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  const _ProfileStatItem({
    super.key,
    required this.count,
    required this.label,
  });

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ProfileDataParser.formatCompactCount(count),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ProfileAvatarPickerSheet extends StatelessWidget {
  const ProfileAvatarPickerSheet({
    super.key,
    this.showCameraOption = true,
  });

  final bool showCameraOption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Cập nhật ảnh đại diện',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('avatar_source_gallery'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                Icons.photo_library_outlined,
                color: colors.primary,
              ),
              title: const Text(
                'Chọn từ thư viện ảnh',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).pop(
                ProfileAvatarSourceOption.gallery,
              ),
            ),
            if (showCameraOption)
              ListTile(
                key: const Key('avatar_source_camera'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: colors.primary,
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.of(context).pop(
                  ProfileAvatarSourceOption.camera,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileSignOutDialog extends StatelessWidget {
  const ProfileSignOutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Đăng xuất'),
      content: const Text(
        'Bạn có chắc muốn đăng xuất khỏi tài khoản SpotShare hiện tại không?',
      ),
      actions: [
        TextButton(
          key: const Key('sign_out_cancel_button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('sign_out_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Đăng xuất',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class ProfileGuestView extends StatelessWidget {
  const ProfileGuestView({
    super.key,
    required this.onLoginTap,
  });

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 34,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đăng nhập để xem hồ sơ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý các địa điểm đã chia sẻ, danh sách đã lưu và bộ sưu tập yêu thích của riêng bạn.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('profile_guest_login_button'),
                    onPressed: onLoginTap,
                    child: const Text(
                      'Đăng nhập ngay',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}