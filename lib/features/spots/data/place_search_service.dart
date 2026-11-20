import 'package:dio/dio.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
  final double latitude;
  final double longitude;
}

class PlaceSearchService {
  PlaceSearchService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  Future<List<PlaceSuggestion>> search(String input) async {
    final trimmed = input.trim();
    if (trimmed.length < 2) {
      return const [];
    }

    try {
      final response = await _dio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q': trimmed,
          'limit': 6,
          'bbox': '102.14,8.18,109.46,23.39',
        },
      );

      final data = response.data;
      if (data is! Map) {
        return const [];
      }

      final features = data['features'];
      if (features is! List) {
        return const [];
      }

      final results = <PlaceSuggestion>[];
      for (final feature in features) {
        if (feature is! Map) continue;

        final geometry = feature['geometry'];
        final coords = (geometry is Map) ? geometry['coordinates'] : null;
        if (coords is! List || coords.length < 2) continue;

        final lng = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final props = feature['properties'];
        if (props is! Map) continue;

        final name = (props['name'] as String?)?.trim() ?? '';
        final street = (props['street'] as String?)?.trim() ?? '';
        final district = (props['district'] as String?)?.trim() ?? '';
        final city = (props['city'] as String?)?.trim() ?? '';
        final county = (props['county'] as String?)?.trim() ?? '';
        final state = (props['state'] as String?)?.trim() ?? '';
        final country = (props['country'] as String?)?.trim() ?? '';

        final addressParts = <String>[
          if (street.isNotEmpty) street,
          if (district.isNotEmpty) district,
          if (city.isNotEmpty) city,
          if (county.isNotEmpty && county != city) county,
          if (state.isNotEmpty && state != city) state,
          if (country.isNotEmpty) country,
        ];

        final mainText = name.isNotEmpty
            ? name
            : (addressParts.isNotEmpty ? addressParts.first : trimmed);

        final secondaryParts = addressParts
            .where((part) => part != mainText)
            .toList();
        final secondaryText = secondaryParts.join(', ');
        final fullText = secondaryText.isNotEmpty
            ? '$mainText, $secondaryText'
            : mainText;

        final osmId = props['osm_id']?.toString() ?? '$lat,$lng';

        results.add(
          PlaceSuggestion(
            placeId: osmId,
            mainText: mainText,
            secondaryText: secondaryText,
            fullText: fullText,
            latitude: lat,
            longitude: lng,
          ),
        );
      }
      return results;
    } on DioException catch (e) {
      throw Exception(
        'Không thể tìm địa chỉ (${e.message ?? 'lỗi kết nối mạng'}).',
      );
    }
  }
}