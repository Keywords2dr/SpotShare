import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/utils/cloudinary_url_helper.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/user_profile_model.dart';
import 'profile_providers.dart';
import 'widgets/profile_spots_grid.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  String? _ensuredUid;

  void _ensureUsernameOnce(User authUser) {
    if (_ensuredUid == authUser.uid) return;
    _ensuredUid = authUser.uid;
    ref.read(profileRepositoryProvider).ensureDefaultUsername(
          userId: authUser.uid,
          email: authUser.email ?? '',
          displayName: authUser.displayName ?? '',
        );
  }

  Future<void> _pickAndUploadAvatar(User authUser) async {
    if (_isUploadingAvatar) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);

      final secureUrl =
          await ref.read(cloudinaryServiceProvider).uploadImage(pickedFile);

      await ref.read(profileRepositoryProvider).updateUserAvatar(
            userId: authUser.uid,
            avatarUrl: secureUrl,
          );
      await authUser.updatePhotoURL(secureUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật ảnh đại diện thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _copyHandle(String handle) async {
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $handle')),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để xem hồ sơ.')),
      );
    }

    _ensureUsernameOnce(authUser);

    final userDataStream =
        ref.watch(profileRepositoryProvider).watchUserData(authUser.uid);
    final theme = Theme.of(context);

    return StreamBuilder(
      stream: userDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final displayName =
            ((data['displayName'] as String?)?.trim().isNotEmpty == true)
                ? (data['displayName'] as String).trim()
                : ((authUser.displayName ?? '').trim().isNotEmpty
                    ? authUser.displayName!.trim()
                    : (authUser.email ?? 'SpotShare User').split('@').first);
        final email = (data['email'] as String?) ?? (authUser.email ?? '');
        final savedUsername =
            (data['username'] as String?)?.trim().toLowerCase() ?? '';
        final fallbackUsername = email.isNotEmpty
            ? UserProfileModel.normalizeUsername(email.split('@').first)
            : authUser.uid.substring(0, 8).toLowerCase();
        final username =
            savedUsername.isNotEmpty ? savedUsername : fallbackUsername;
        final handle = '@$username';

        final rawAvatar =
            ((data['avatarUrl'] as String?)?.trim().isNotEmpty == true)
                ? (data['avatarUrl'] as String).trim()
                : (authUser.photoURL ?? '');
        final avatarUrl = rawAvatar.isNotEmpty
            ? CloudinaryUrlHelper.feedThumbnail(rawAvatar)
            : '';
        final bio = (data['bio'] as String?)?.trim() ?? '';
        final followingCount = (data['followingCount'] as num?)?.toInt() ?? 0;
        final followersCount = (data['followersCount'] as num?)?.toInt() ?? 0;
        final totalLikes = (data['totalLikes'] as num?)?.toInt() ?? 0;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => context.push('/profile/edit'),
                tooltip: 'Sửa hồ sơ',
                icon: const Icon(Icons.edit_outlined),
              ),
              actions: [
                IconButton(
                  onPressed: _signOut,
                  tooltip: 'Đăng xuất',
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  InkWell(
                                    onTap: () => _copyHandle(handle),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              handle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      _StatItem(
                                        count: followingCount,
                                        label: 'Đã follow',
                                      ),
                                      const SizedBox(width: 20),
                                      _StatItem(
                                        count: followersCount,
                                        label: 'Follower',
                                      ),
                                      const SizedBox(width: 20),
                                      _StatItem(
                                        count: totalLikes,
                                        label: 'Thích',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _isUploadingAvatar
                                  ? null
                                  : () => _pickAndUploadAvatar(authUser),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            avatarUrl,
                                          )
                                        : null,
                                    child: _isUploadingAvatar
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          )
                                        : (avatarUrl.isEmpty
                                            ? Text(
                                                displayName.isNotEmpty
                                                    ? displayName[0]
                                                        .toUpperCase()
                                                    : 'S',
                                                style: theme
                                                    .textTheme.headlineMedium
                                                    ?.copyWith(
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
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surface,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 15,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (bio.isEmpty)
                          InkWell(
                            onTap: () => context.push('/profile/edit'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
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
                          InkWell(
                            onTap: () => context.push('/profile/edit'),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      bio,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarSliverDelegate(
                    TabBar(
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.grid_on_rounded),
                          text: 'Bài đăng',
                        ),
                        Tab(
                          icon: Icon(Icons.bookmark_border_rounded),
                          text: 'Đã lưu',
                        ),
                        Tab(
                          icon: Icon(Icons.favorite_border_rounded),
                          text: 'Yêu thích',
                        ),
                      ],
                    ),
                    backgroundColor: theme.colorScheme.surface,
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  ProfileSpotsGrid(
                    provider: userSpotsProvider(authUser.uid),
                    emptyIcon: Icons.photo_library_outlined,
                    emptyTitle: 'Chia sẻ tọa độ đầu tiên của bạn',
                    emptySubtitle:
                        'Các địa điểm bạn đăng tải sẽ hiển thị tại đây.',
                    actionLabel: 'Tải lên',
                    onAction: () => context.go('/create'),
                  ),
                  ProfileSpotsGrid(
                    provider: savedSpotsProvider(authUser.uid),
                    emptyIcon: Icons.bookmark_border_rounded,
                    emptyTitle: 'Chưa có địa điểm đã lưu',
                    emptySubtitle:
                        'Bấm biểu tượng Lưu trong trang chi tiết địa điểm để xem lại sau.',
                  ),
                  ProfileSpotsGrid(
                    provider: likedSpotsProvider(authUser.uid),
                    emptyIcon: Icons.favorite_border_rounded,
                    emptyTitle: 'Chưa có địa điểm yêu thích',
                    emptySubtitle:
                        'Những địa điểm bạn thả tim sẽ xuất hiện tại đây.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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
      children: [
        Text(
          '$count',
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

class _TabBarSliverDelegate extends SliverPersistentHeaderDelegate {
  _TabBarSliverDelegate(this.tabBar, {required this.backgroundColor});

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarSliverDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}