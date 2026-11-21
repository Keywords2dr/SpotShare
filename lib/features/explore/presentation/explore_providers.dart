import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../spots/domain/spot_model.dart';
import '../../spots/presentation/spot_providers.dart';
import '../domain/explore_ranking.dart';

class ExploreSortModeNotifier extends Notifier<ExploreSortMode> {
  @override
  ExploreSortMode build() => ExploreSortMode.trending;

  void setMode(ExploreSortMode mode) {
    state = mode;
  }
}

final exploreSortModeProvider =
    NotifierProvider<ExploreSortModeNotifier, ExploreSortMode>(
  ExploreSortModeNotifier.new,
);

class ExploreSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final exploreSearchQueryProvider =
    NotifierProvider<ExploreSearchQueryNotifier, String>(
  ExploreSearchQueryNotifier.new,
);

final exploreSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(spotRepositoryProvider).watchRecentSpots(limit: 50);
});

final rankedExploreSpotsProvider = Provider<AsyncValue<List<SpotModel>>>((ref) {
  final spotsAsync = ref.watch(exploreSpotsProvider);
  final sortMode = ref.watch(exploreSortModeProvider);
  final rawQuery = ref.watch(exploreSearchQueryProvider).trim().toLowerCase();

  return spotsAsync.whenData((spots) {
    final sorted = sortExploreSpots(spots, sortMode);
    if (rawQuery.isEmpty) return sorted;

    return sorted.where((spot) {
      final title = spot.title.toLowerCase();
      final address = spot.addressText.toLowerCase();
      final category = spot.category.toLowerCase();
      final description = spot.description.toLowerCase();
      return title.contains(rawQuery) ||
          address.contains(rawQuery) ||
          category.contains(rawQuery) ||
          description.contains(rawQuery);
    }).toList();
  });
});