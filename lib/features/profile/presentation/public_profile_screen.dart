import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/cloudinary_url_helper.dart';
import 'profile_providers.dart';
import 'widgets/profile_spots_grid.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _isTogglingFollow = false;

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để theo dõi.')),
      );
      return;
    }

    setState(() => _isTogglingFollow = true);
    try {
      await ref.read(profileRepositoryProvider).toggleFollow(
            currentUserId: authUser.uid,
            targetUserId: widget.userId,
          );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật theo dõi: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTogglingFollow = false);
      }
    }
  }

  Future<void> _copyHandle(String handle) async {
    if (handle.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $handle')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == widget.userId;
    final isFollowing =
        ref.watch(isFollowingProvider(widget.userId)).value ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(profileAsync.value?.handle ?? 'Hồ sơ'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Không thể tải hồ sơ người dùng: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Không tìm thấy tài khoản này.'),
            );
          }

          final avatarUrl = profile.avatarUrl.isNotEmpty
              ? CloudinaryUrlHelper.feedThumbnail(profile.avatarUrl)
              : '';

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                  profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () => _copyHandle(profile.handle),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          profile.handle,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
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
                                    _PublicStatItem(
                                      count: profile.followingCount,
                                      label: 'Đã follow',
                                    ),
                                    const SizedBox(width: 20),
                                    _PublicStatItem(
                                      count: profile.followersCount,
                                      label: 'Follower',
                                    ),
                                    const SizedBox(width: 20),
                                    _PublicStatItem(
                                      count: profile.totalLikes,
                                      label: 'Thích',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 42,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    profile.displayName.isNotEmpty
                                        ? profile.displayName[0].toUpperCase()
                                        : 'S',
                                    style:
                                        theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          profile.bio,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (!isOwnProfile) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: isFollowing
                              ? OutlinedButton.icon(
                                  onPressed:
                                      _isTogglingFollow ? null : _toggleFollow,
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const Text('Đang follow'),
                                )
                              : FilledButton.icon(
                                  onPressed:
                                      _isTogglingFollow ? null : _toggleFollow,
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Follow'),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.grid_on_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bài đăng',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            body: ProfileSpotsGrid(
              provider: userSpotsProvider(widget.userId),
              emptyIcon: Icons.photo_library_outlined,
              emptyTitle: 'Chưa có bài đăng nào',
              emptySubtitle:
                  'Người dùng này chưa chia sẻ địa điểm nào trên SpotShare.',
            ),
          );
        },
      ),
    );
  }
}

class _PublicStatItem extends StatelessWidget {
  const _PublicStatItem({
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