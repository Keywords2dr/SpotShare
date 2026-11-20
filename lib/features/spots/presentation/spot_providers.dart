import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/spot_repository.dart';
import '../domain/spot_model.dart';

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  return SpotRepository();
});

final spotDetailProvider = StreamProvider.family<SpotModel?, String>((
  ref,
  spotId,
) {
  return ref.watch(spotRepositoryProvider).watchSpotById(spotId);
});