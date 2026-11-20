import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloudinary_service.dart';
import 'place_search_service.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  return PlaceSearchService();
});