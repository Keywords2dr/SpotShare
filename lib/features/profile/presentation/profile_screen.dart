import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/utils/cloudinary_url_helper.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../spots/presentation/like/spot_like_controller.dart';
import '../domain/user_profile_model.dart';
import 'liked_spots_controller.dart';
import 'profile_providers.dart';
import 'widgets/liked_spots_tab.dart';
import 'widgets/profile_screen_support.dart';
import 'widgets/profile_spots_grid.dart';

final profileUserDataStreamProvider =
    StreamProvider.autoDispose.family<ProfileDataMap, String>((ref, userId) {
  return ref
      .watch(profileRepositoryProvider)
      .watchUserData(userId)
      .map<ProfileDataMap>((Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return const <String, dynamic>{};
  });
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  bool _isSigningOut = false;
  String? _ensuredUid;

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _ensureUsernameOnce(User authUser) {
    if (_ensuredUid == authUser.uid) return;
    _ensuredUid = authUser.uid;
    ref
        .read(profileRepositoryProvider)
        .ensureDefaultUsername(
          userId: authUser.uid,
          email: authUser.email ?? '',
          displayName: authUser.displayName ?? '',
        )
        .catchError((Object e) {
      if (kDebugMode) {
        debugPrint('[ProfileScreen] ensureDefaultUsername skipped: $e');
      }
    });
  }

  Future<void> _pickAndUploadAvatar(User authUser) async {
    if (_isUploadingAvatar) return;

    ProfileAvatarSourceOption? chosenSource;
    if (kIsWeb) {
      chosenSource = ProfileAvatarSourceOption.gallery;
    } else {
      chosenSource = await showModalBottomSheet<ProfileAvatarSourceOption>(
        context: context,
        useSafeArea: true,
        builder: (_) => const ProfileAvatarPickerSheet(
          showCameraOption: true,
        ),
      );
    }
    if (chosenSource == null || !mounted) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: chosenSource == ProfileAvatarSourceOption.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 80,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);

      final secureUrl =
          await ref.read(cloudinaryServiceProvider).uploadImage(pickedFile);

      await ref.read(profileRepositoryProvider).updateUserAvatar(
            userId: authUser.uid,
            avatarUrl: secureUrl,
          );
      try {
        await authUser.updatePhotoURL(secureUrl);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ProfileScreen] updatePhotoURL non-fatal error: $e');
        }
      }

      if (!mounted) return;
      _showSnackBar('Đã cập nhật ảnh đại diện!');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileScreen] uploadAvatar failed: $e');
      }
      _showSnackBar(
        ProfileErrorMapper.map(
          e,
          fallback: 'Cập nhật ảnh đại diện thất bại. Vui lòng thử lại.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _copyHandle(String handle) async {
    await Clipboard.setData(ClipboardData(text: handle));
    _showSnackBar('Đã sao chép $handle');
  }

  void _refreshProfile(String userId) {
    ref.invalidate(profileUserDataStreamProvider(userId));
    ref.invalidate(userSpotsProvider(userId));
    ref.invalidate(savedSpotsProvider(userId));
    ref.read(likedSpotsControllerProvider.notifier).load(
          userId: userId,
          forceRefresh: true,
          cleanupOrphans: true,
        );
  }

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ProfileSignOutDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      ref.read(spotLikeControllerProvider.notifier).clearAll();
      ref.read(likedSpotsControllerProvider.notifier).clearAll();
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileScreen] signOut failed: $e');
      }
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      _showSnackBar(
        ProfileErrorMapper.map(
          e,
          fallback: 'Đăng xuất thất bại. Vui lòng thử lại.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return ProfileGuestView(
        onLoginTap: () => context.go('/login'),
      );
    }

    _ensureUsernameOnce(authUser);

    final userDataAsync =
        ref.watch(profileUserDataStreamProvider(authUser.uid));
    final data = userDataAsync.value ?? const <String, dynamic>{};
    final liveSpotsCount =
        ref.watch(userSpotsProvider(authUser.uid)).value?.length;

    final profile = ProfileDataParser.parse(
      data: data,
      uid: authUser.uid,
      authDisplayName: authUser.displayName,
      authEmail: authUser.email,
      authPhotoUrl: authUser.photoURL,
      liveSpotsCount: liveSpotsCount,
      normalizeUsername: UserProfileModel.normalizeUsername,
      formatAvatarUrl: CloudinaryUrlHelper.feedThumbnail,
    );

    final errorMessage = userDataAsync.hasError
        ? ProfileErrorMapper.map(
            userDataAsync.error!,
            fallback: 'Không thể đồng bộ hồ sơ. Đang hiển thị dữ liệu tạm.',
          )
        : null;

    final theme = Theme.of(context);

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
              onPressed: () => _refreshProfile(authUser.uid),
              tooltip: 'Làm mới hồ sơ',
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (_isSigningOut)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: _confirmAndSignOut,
                tooltip: 'Đăng xuất',
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: ProfileHeaderSection(
                profile: profile,
                isUploadingAvatar: _isUploadingAvatar,
                errorMessage: errorMessage,
                onRetry: () => _refreshProfile(authUser.uid),
                onCopyHandle: () => _copyHandle(profile.handle),
                onEditProfile: () => context.push('/profile/edit'),
                onPickAvatar: () => _pickAndUploadAvatar(authUser),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarSliverDelegate(
                const TabBar(
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
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
              LikedSpotsTab(
                userId: authUser.uid,
                isOwnProfile: true,
              ),
            ],
          ),
        ),
      ),
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