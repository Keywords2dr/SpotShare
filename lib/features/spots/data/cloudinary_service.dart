import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CloudinaryService {
  CloudinaryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  static const int _maxBytes = 600 * 1024;

  String get _cloudName {
    final value = (dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').trim();
    if (value.isEmpty) {
      throw Exception('Thiếu biến CLOUDINARY_CLOUD_NAME trong file .env.');
    }
    return value;
  }

  String get _uploadPreset {
    final value = (dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '').trim();
    if (value.isEmpty) {
      throw Exception('Thiếu biến CLOUDINARY_UPLOAD_PRESET trong file .env.');
    }
    return value;
  }

  Future<Uint8List> _compressToUnder600Kb(XFile file) async {
    final rawBytes = await file.readAsBytes();
    if (kIsWeb) {
      return rawBytes;
    }

    int quality = 80;
    Uint8List result = rawBytes;

    while (result.lengthInBytes > _maxBytes && quality >= 35) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed == null || compressed.isEmpty) {
        break;
      }
      result = Uint8List.fromList(compressed);
      quality -= 15;
    }

    return result;
  }

  Future<String> uploadImage(
    XFile file, {
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await _compressToUnder600Kb(file);
    final fileName = file.name.isNotEmpty
        ? file.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg')
        : 'spot_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final endpoint =
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

    final formData = FormData.fromMap({
      'upload_preset': _uploadPreset,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
    });

    try {
      final response = await _dio.post(
        endpoint,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );

      final data = response.data;
      if (data is Map) {
        final secureUrl = (data['secure_url'] as String?) ?? '';
        if (secureUrl.isNotEmpty) {
          onProgress?.call(1.0);
          return secureUrl;
        }
      }
      throw Exception('Cloudinary không trả về đường dẫn ảnh hợp lệ.');
    } on DioException catch (e) {
      final serverMessage = e.response?.data is Map
          ? (e.response?.data['error']?['message']?.toString() ?? '')
          : '';
      if (serverMessage.isNotEmpty) {
        throw Exception('Upload ảnh thất bại: $serverMessage');
      }
      throw Exception('Không thể tải ảnh lên Cloudinary (${e.message ?? 'lỗi mạng'}).');
    }
  }

  Future<List<String>> uploadImages(
    List<XFile> files, {
    void Function(int currentIndex, int totalCount, double fileProgress)?
        onFileProgress,
  }) async {
    if (files.isEmpty) {
      throw Exception('Vui lòng chọn ít nhất 1 ảnh địa điểm.');
    }
    if (files.length > 6) {
      throw Exception('Chỉ được chọn tối đa 6 ảnh cho mỗi địa điểm.');
    }

    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final url = await uploadImage(
        files[i],
        onProgress: (progress) {
          onFileProgress?.call(i, files.length, progress);
        },
      );
      urls.add(url);
    }
    return urls;
  }
}