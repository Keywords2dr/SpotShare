import 'dart:math' as math;

import '../../spots/domain/spot_model.dart';

enum ExploreSortMode {
  trending,
  newest,
}

double calculateSpotTrendingScore(SpotModel spot, DateTime now) {
  final engagement = (spot.likesCount * 2.0) +
      (spot.ratingCount * 3.0) +
      (spot.ratingAvg * spot.ratingCount * 0.5) +
      1.0;
  final createdAt = spot.createdAt ?? now;
  final ageInHours = math.max(0.0, now.difference(createdAt).inMinutes / 60.0);
  final gravity = math.pow(ageInHours + 2.0, 1.2).toDouble();
  return engagement / gravity;
}

List<SpotModel> sortExploreSpots(
  List<SpotModel> spots,
  ExploreSortMode sortMode,
) {
  final sorted = List<SpotModel>.from(spots);
  if (sortMode == ExploreSortMode.trending) {
    final now = DateTime.now();
    sorted.sort((a, b) {
      final scoreB = calculateSpotTrendingScore(b, now);
      final scoreA = calculateSpotTrendingScore(a, now);
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;
      final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
  } else {
    sorted.sort((a, b) {
      final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
  }
  return sorted;
}