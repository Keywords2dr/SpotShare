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

final exploreSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(spotRepositoryProvider).watchRecentSpots(limit: 50);
});

final rankedExploreSpotsProvider = Provider<AsyncValue<List<SpotModel>>>((ref) {
  final spotsAsync = ref.watch(exploreSpotsProvider);
  final sortMode = ref.watch(exploreSortModeProvider);

  return spotsAsync.whenData((spots) => sortExploreSpots(spots, sortMode));
});