import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/cloudinary_url_helper.dart';
import '../../profile/domain/user_profile_model.dart';
import '../../profile/presentation/profile_providers.dart';
import '../domain/explore_ranking.dart';
import 'explore_providers.dart';
import 'widgets/spot_grid_card.dart';

class ExploreFeedScreen extends ConsumerStatefulWidget {
  const ExploreFeedScreen({super.key});

  @override
  ConsumerState<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends ConsumerState<ExploreFeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(exploreSearchQueryProvider.notifier).setQuery(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(exploreSearchQueryProvider.notifier).clear();
    setState(() {});
  }

  void _openUserProfile(UserProfileModel user) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null && user.uid == currentUserId) {
      context.go('/profile');
    } else {
      context.push('/users/${user.uid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(rankedExploreSpotsProvider);
    final sortMode = ref.watch(exploreSortModeProvider);
    final searchQuery = ref.watch(exploreSearchQueryProvider).trim();
    final isSearching = searchQuery.isNotEmpty;
    final usersAsync =
        isSearching ? ref.watch(userSearchProvider(searchQuery)) : null;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm địa điểm hoặc @khóa_định_danh...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        tooltip: 'Xóa từ khóa',
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor:
                    colors.surfaceContainerHighest.withValues(alpha: 0.7),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: colors.primary.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                  ),
                  label: const Text('Đề xuất'),
                  selected: sortMode == ExploreSortMode.trending,
                  onSelected: (_) => ref
                      .read(exploreSortModeProvider.notifier)
                      .setMode(ExploreSortMode.trending),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('Mới nhất'),
                  selected: sortMode == ExploreSortMode.newest,
                  onSelected: (_) => ref
                      .read(exploreSortModeProvider.notifier)
                      .setMode(ExploreSortMode.newest),
                ),
              ],
            ),
          ),
          Expanded(
            child: spotsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Không thể tải bảng tin: $error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(exploreSpotsProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (spots) {
                final matchedUsers = usersAsync?.value ?? const <UserProfileModel>[];
                final isLoadingUsers = usersAsync?.isLoading ?? false;

                if (!isSearching && spots.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_off_outlined,
                            size: 56,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có địa điểm nào',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hãy chuyển sang tab Đăng bài để chia sẻ tọa độ đầu tiên.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (isSearching &&
                    spots.isEmpty &&
                    matchedUsers.isEmpty &&
                    !isLoadingUsers) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Không tìm thấy kết quả cho "$searchQuery"',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Thử nhập @khóa_định_danh hoặc tên địa điểm khác.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonal(
                            onPressed: _clearSearch,
                            child: const Text('Xóa tìm kiếm'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(exploreSpotsProvider);
                    if (isSearching) {
                      ref.invalidate(userSearchProvider(searchQuery));
                    }
                    await ref.read(exploreSpotsProvider.future);
                  },
                  child: CustomScrollView(
                    slivers: [
                      if (isSearching && (isLoadingUsers || matchedUsers.isNotEmpty))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Người dùng',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (isLoadingUsers && matchedUsers.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Card(
                                    margin: EdgeInsets.zero,
                                    clipBehavior: Clip.antiAlias,
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: matchedUsers.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final user = matchedUsers[index];
                                        final avatarUrl = user.avatarUrl.isNotEmpty
                                            ? CloudinaryUrlHelper.feedThumbnail(
                                                user.avatarUrl,
                                              )
                                            : '';
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundImage: avatarUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    avatarUrl,
                                                  )
                                                : null,
                                            child: avatarUrl.isEmpty
                                                ? Text(
                                                    user.displayName.isNotEmpty
                                                        ? user.displayName[0]
                                                            .toUpperCase()
                                                        : 'S',
                                                  )
                                                : null,
                                          ),
                                          title: Text(
                                            user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${user.handle} · ${user.spotsCount} bài đăng',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                          onTap: () => _openUserProfile(user),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (isSearching && spots.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Text(
                              'Địa điểm',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (spots.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => SpotGridCard(
                                spot: spots[index],
                              ),
                              childCount: spots.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}