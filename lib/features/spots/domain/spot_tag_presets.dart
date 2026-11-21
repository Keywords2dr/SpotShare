class SpotTagPresets {
  const SpotTagPresets._();

  static const List<String> defaultCategories = [
    'Bãi biển',
    'Cảnh đẹp / Check-in',
    'Món ăn ngon',
    'Quán cà phê view đẹp',
    'Cắm trại / Chill',
    'Di tích / Văn hóa',
  ];

  static bool isFoodOrCafe(String category) {
    final lower = category.toLowerCase();
    return lower.contains('món ăn') ||
        lower.contains('ẩm thực') ||
        lower.contains('quán') ||
        lower.contains('cà phê') ||
        lower.contains('cafe');
  }

  static String bestTimeLabelFor(String category) {
    if (isFoodOrCafe(category)) {
      return 'Khung giờ nên ghé';
    }
    return 'Giờ đẹp nhất';
  }

  static String transportLabelFor(String category) {
    return 'Phương tiện di chuyển';
  }

  static String priceLabelFor(String category) {
    return 'Khoảng giá tham khảo';
  }

  static List<String> bestTimeOptionsFor(String category) {
    if (category == 'Món ăn ngon') {
      return const [
        'Bữa sáng (6h–9h)',
        'Bữa trưa (11h–13h)',
        'Ăn vặt chiều (15h–18h)',
        'Bữa tối / Ăn khuya',
        'Cả ngày',
      ];
    }
    if (category == 'Quán cà phê view đẹp') {
      return const [
        'Sáng sớm chill (7h–9h)',
        'Chiều hoàng hôn (16h–18h)',
        'Buổi tối / Ngắm đèn',
        'Cả ngày / Làm việc',
      ];
    }
    if (category == 'Cắm trại / Chill') {
      return const [
        'Chiều tới sáng hôm sau',
        'Đón bình minh (5h–7h)',
        'Chiều hoàng hôn (16h–18h)',
        'Cuối tuần',
      ];
    }
    return const [
      'Bình minh (5h–7h)',
      'Sáng sớm (6h–9h)',
      'Chiều hoàng hôn (16h–18h)',
      'Buổi tối / Đêm',
      'Cả ngày',
    ];
  }

  static List<String> transportOptionsFor(String category) {
    if (category == 'Bãi biển') {
      return const [
        'Xe máy',
        'Ô tô',
        'Đi bộ',
        'Cano / Thuyền',
        'Xe đạp',
      ];
    }
    if (isFoodOrCafe(category)) {
      return const [
        'Xe máy',
        'Ô tô',
        'Đi bộ',
        'Taxi / Xe công nghệ',
        'Xe đạp',
      ];
    }
    return const [
      'Xe máy',
      'Ô tô',
      'Đi bộ / Trekking',
      'Xe đạp',
      'Xe buýt / Taxi',
    ];
  }

  static List<String> priceOptionsFor(String category) {
    if (isFoodOrCafe(category)) {
      return const [
        '< 50k',
        '50k – 150k',
        '150k – 300k',
        '> 300k',
      ];
    }
    return const [
      'Miễn phí',
      '< 50k',
      '50k – 150k',
      '> 150k',
    ];
  }

  static List<String> parseMultiTag(String raw) {
    if (raw.trim().isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final part in raw.split(',')) {
      final cleaned = part.trim();
      if (cleaned.isNotEmpty && seen.add(cleaned.toLowerCase())) {
        result.add(cleaned);
      }
    }
    return result;
  }

  static String joinMultiTag(List<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in tags) {
      final cleaned = tag.trim();
      if (cleaned.isNotEmpty && seen.add(cleaned.toLowerCase())) {
        result.add(cleaned);
      }
    }
    return result.join(', ');
  }
}