import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/explore_ranking.dart';
import 'explore_providers.dart';
import 'widgets/spot_grid_card.dart';

class ExploreFeedScreen extends ConsumerWidget {
  const ExploreFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(rankedExploreSpotsProvider);
    final sortMode = ref.watch(exploreSortModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám phá'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                if (spots.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_off_outlined,
                            size: 56,
                            color: theme.colorScheme.onSurfaceVariant,
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
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(exploreSpotsProvider);
                    await ref.read(exploreSpotsProvider.future);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: spots.length,
                    itemBuilder: (context, index) {
                      return SpotGridCard(spot: spots[index]);
                    },
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