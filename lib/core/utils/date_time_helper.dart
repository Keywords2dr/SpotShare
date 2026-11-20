class DateTimeHelper {
  const DateTimeHelper._();

  static String formatCardTime(DateTime? date) {
    if (date == null) return 'Vừa xong';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24 && date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${diff.inHours} giờ trước';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Hôm qua ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    }
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  static String formatFullPostTime(DateTime? date) {
    if (date == null) return 'Vừa xong';
    final exact =
        '${_twoDigits(date.hour)}:${_twoDigits(date.minute)} •${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'Vừa xong ($exact)';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước • $exact';
    }
    if (diff.inHours < 24 && date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${diff.inHours} giờ trước • $exact';
    }
    return 'Đăng lúc $exact';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}