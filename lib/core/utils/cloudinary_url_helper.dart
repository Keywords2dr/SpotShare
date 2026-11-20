class CloudinaryUrlHelper {
  const CloudinaryUrlHelper._();

  static String optimize(
    String secureUrl, {
    int width = 600,
  }) {
    if (secureUrl.isEmpty || !secureUrl.contains('/image/upload/')) {
      return secureUrl;
    }
    const marker = '/image/upload/';
    final transformation = '${marker}f_auto,q_auto,w_$width/';
    return secureUrl.replaceFirst(marker, transformation);
  }

  static String feedThumbnail(String secureUrl) => optimize(secureUrl, width: 600);

  static String detailImage(String secureUrl) => optimize(secureUrl, width: 1400);
}