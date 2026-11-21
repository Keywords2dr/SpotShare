import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final spotDetailCurrentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

enum SpotReportReason {
  wrongLocation('wrong_location', 'Sai vị trí hoặc tọa độ GPS'),
  permanentlyClosed('permanently_closed', 'Địa điểm đã đóng cửa'),
  inappropriateContent(
    'inappropriate_content',
    'Hình ảnh hoặc nội dung không phù hợp',
  ),
  spamOrFake('spam_or_fake', 'Thông tin sai lệch / Quảng cáo rác');

  const SpotReportReason(this.code, this.label);

  final String code;
  final String label;
}

class SpotDetailException implements Exception {
  const SpotDetailException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class SpotDetailErrorMapper {
  static String map(
    Object error, {
    required String fallback,
  }) {
    if (error is SpotDetailException) {
      return error.message;
    }

    String? code;
    if (error is FirebaseException) {
      code = error.code;
    }

    final raw = error.toString().toLowerCase();
    final resolvedCode = code ?? _extractCodeFromRaw(raw);

    switch (resolvedCode) {
      case 'permission-denied':
        return 'Bạn chưa có quyền thực hiện thao tác này. Vui lòng kiểm tra phiên đăng nhập hoặc quy tắc bảo mật.';
      case 'unauthenticated':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'not-found':
        return 'Bài viết này không còn tồn tại hoặc đã bị xóa.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Mất kết nối mạng hoặc máy chủ phản hồi chậm. Vui lòng thử lại.';
      case 'aborted':
        return 'Dữ liệu đang được cập nhật đồng thời. Vui lòng thử lại sau giây lát.';
      default:
        return fallback;
    }
  }

  static String? _extractCodeFromRaw(String raw) {
    if (raw.contains('permission-denied')) return 'permission-denied';
    if (raw.contains('unauthenticated')) return 'unauthenticated';
    if (raw.contains('not-found')) return 'not-found';
    if (raw.contains('unavailable') || raw.contains('network-request-failed')) {
      return 'unavailable';
    }
    if (raw.contains('deadline-exceeded')) return 'deadline-exceeded';
    if (raw.contains('aborted')) return 'aborted';
    return null;
  }
}

class SpotCoordinatesHelper {
  static bool isValid(double latitude, double longitude) {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static String format(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  static String googleMapsUrl(double latitude, double longitude) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  static String buildShareSummary({
    required String title,
    required String category,
    required String addressText,
    required double latitude,
    required double longitude,
  }) {
    final buffer = StringBuffer()..writeln('$title ($category)');
    if (addressText.trim().isNotEmpty) {
      buffer.writeln('Địa chỉ: ${addressText.trim()}');
    }
    if (isValid(latitude, longitude)) {
      buffer.writeln('Google Maps: ${googleMapsUrl(latitude, longitude)}');
    }
    return buffer.toString().trim();
  }
}

class SpotOptimisticResolver {
  static bool resolveBool({
    required bool serverValue,
    required bool? pendingValue,
    required bool isProcessing,
  }) {
    if (isProcessing && pendingValue != null) {
      return pendingValue;
    }
    if (pendingValue != null && pendingValue != serverValue) {
      return pendingValue;
    }
    return serverValue;
  }

  static int resolveCount({
    required int serverCount,
    required bool serverActive,
    required bool? pendingActive,
    required int? pendingCount,
    required bool isProcessing,
  }) {
    final safeServer = serverCount < 0 ? 0 : serverCount;
    if (isProcessing && pendingCount != null) {
      return pendingCount < 0 ? 0 : pendingCount;
    }
    if (pendingActive != null &&
        pendingCount != null &&
        pendingActive != serverActive) {
      return pendingCount < 0 ? 0 : pendingCount;
    }
    return safeServer;
  }

  static int nextCount({
    required int currentCount,
    required bool willBeActive,
  }) {
    final safeCurrent = currentCount < 0 ? 0 : currentCount;
    if (willBeActive) return safeCurrent + 1;
    return safeCurrent > 0 ? safeCurrent - 1 : 0;
  }
}

abstract class SpotReportGateway {
  Future<void> submitReport({
    required String spotId,
    required String spotTitle,
    required String reporterId,
    required SpotReportReason reason,
    String note = '',
  });
}

class FirestoreSpotReportRepository implements SpotReportGateway {
  FirestoreSpotReportRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> submitReport({
    required String spotId,
    required String spotTitle,
    required String reporterId,
    required SpotReportReason reason,
    String note = '',
  }) async {
    if (reporterId.trim().isEmpty) {
      throw const SpotDetailException(
        'Vui lòng đăng nhập để gửi báo cáo vi phạm.',
        code: 'unauthenticated',
      );
    }
    if (spotId.trim().isEmpty) {
      throw const SpotDetailException(
        'Không xác định được bài viết cần báo cáo.',
        code: 'invalid-argument',
      );
    }

    try {
      await _db.collection('reports').add({
        'spotId': spotId.trim(),
        'spotTitle': spotTitle.trim(),
        'reporterId': reporterId.trim(),
        'reasonCode': reason.code,
        'reasonLabel': reason.label,
        'note': note.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotReportRepository] submitReport failed (${e.code}): ${e.message}',
        );
      }
      throw SpotDetailException(
        SpotDetailErrorMapper.map(
          e,
          fallback: 'Không thể gửi báo cáo lúc này. Vui lòng thử lại.',
        ),
        code: e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotReportRepository] submitReport unexpected error: $e');
      }
      throw const SpotDetailException(
        'Không thể gửi báo cáo lúc này. Vui lòng kiểm tra kết nối mạng và thử lại.',
        code: 'unknown',
      );
    }
  }
}

final spotReportGatewayProvider = Provider<SpotReportGateway>((ref) {
  return FirestoreSpotReportRepository();
});

class SpotQuickTagData {
  const SpotQuickTagData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class SpotActionBar extends StatelessWidget {
  const SpotActionBar({
    super.key,
    required this.isLiked,
    required this.likesCount,
    required this.isSaved,
    required this.ratingAvg,
    required this.ratingCount,
    this.isLikeDisabled = false,
    this.isSaveDisabled = false,
    this.onLikeTap,
    this.onCommentTap,
    this.onSaveTap,
  });

  final bool isLiked;
  final int likesCount;
  final bool isSaved;
  final double ratingAvg;
  final int ratingCount;
  final bool isLikeDisabled;
  final bool isSaveDisabled;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onSaveTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final safeLikes = likesCount < 0 ? 0 : likesCount;
    final safeRatings = ratingCount < 0 ? 0 : ratingCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _SpotCounterActionButton(
            key: const Key('spot_detail_like_button'),
            tooltip: isLiked ? 'Bỏ thích' : 'Thích địa điểm',
            icon: isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            activeColor: colors.error,
            isActive: isLiked,
            animateScale: true,
            label: '$safeLikes',
            onTap: isLikeDisabled ? null : onLikeTap,
          ),
          const SizedBox(width: 6),
          _SpotCounterActionButton(
            key: const Key('spot_detail_comment_button'),
            tooltip: 'Viết đánh giá & bình luận',
            icon: Icons.chat_bubble_outline_rounded,
            label: '$safeRatings',
            onTap: onCommentTap,
          ),
          const SizedBox(width: 6),
          _SpotCounterActionButton(
            key: const Key('spot_detail_save_button'),
            tooltip: isSaved ? 'Bỏ khỏi mục Đã lưu' : 'Lưu địa điểm',
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            activeColor: colors.primary,
            isActive: isSaved,
            label: isSaved ? 'Đã lưu' : 'Lưu',
            onTap: isSaveDisabled ? null : onSaveTap,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 17,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  safeRatings > 0
                      ? '${ratingAvg.toStringAsFixed(1)} ($safeRatings)'
                      : 'Chưa có',
                  key: const Key('spot_detail_rating_text'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotCounterActionButton extends StatelessWidget {
  const _SpotCounterActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    this.activeColor,
    this.isActive = false,
    this.animateScale = false,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final Color? activeColor;
  final bool isActive;
  final bool animateScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        isActive ? (activeColor ?? colors.primary) : colors.onSurfaceVariant;
    final background = isActive
        ? (activeColor ?? colors.primary).withValues(alpha: 0.12)
        : Colors.transparent;

    final iconWidget = Icon(icon, size: 19, color: foreground);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (animateScale)
                  AnimatedScale(
                    scale: isActive ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: iconWidget,
                  )
                else
                  iconWidget,
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SpotCoordinatesCard extends StatelessWidget {
  const SpotCoordinatesCard({
    super.key,
    required this.tags,
    required this.latitude,
    required this.longitude,
    required this.onCopyCoordinates,
    required this.onCopyMapsLink,
  });

  final List<SpotQuickTagData> tags;
  final double latitude;
  final double longitude;
  final VoidCallback onCopyCoordinates;
  final VoidCallback onCopyMapsLink;

  @override
  Widget build(BuildContext context) {
    final hasValidCoords = SpotCoordinatesHelper.isValid(latitude, longitude);
    if (tags.isEmpty && !hasValidCoords) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.55),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tag.icon,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tag.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (tags.isNotEmpty && hasValidCoords) const SizedBox(height: 10),
            if (hasValidCoords) ...[
              Row(
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tọa độ: ${SpotCoordinatesHelper.format(latitude, longitude)}',
                      key: const Key('spot_detail_coordinates_text'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CompactActionPill(
                    key: const Key('spot_detail_copy_coords_button'),
                    icon: Icons.copy_rounded,
                    label: 'Sao chép tọa độ',
                    onTap: onCopyCoordinates,
                  ),
                  _CompactActionPill(
                    key: const Key('spot_detail_copy_maps_button'),
                    icon: Icons.directions_outlined,
                    label: 'Sao chép link Maps',
                    onTap: onCopyMapsLink,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactActionPill extends StatelessWidget {
  const _CompactActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.65),
      shape: StadiumBorder(
        side: BorderSide(
          color: colors.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpotDetailErrorView extends StatelessWidget {
  const SpotDetailErrorView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.onBack,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (onRetry != null)
                    FilledButton.icon(
                      key: const Key('spot_detail_retry_button'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Thử lại'),
                    ),
                  if (onBack != null)
                    OutlinedButton(
                      key: const Key('spot_detail_back_button'),
                      onPressed: onBack,
                      child: const Text('Quay lại'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpotReportSheet extends ConsumerStatefulWidget {
  const SpotReportSheet({
    super.key,
    required this.spotId,
    required this.spotTitle,
    required this.reporterId,
    this.onSubmitted,
  });

  final String spotId;
  final String spotTitle;
  final String reporterId;
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<SpotReportSheet> createState() => _SpotReportSheetState();
}

class _SpotReportSheetState extends ConsumerState<SpotReportSheet> {
  SpotReportReason _selectedReason = SpotReportReason.wrongLocation;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(spotReportGatewayProvider).submitReport(
            spotId: widget.spotId,
            spotTitle: widget.spotTitle,
            reporterId: widget.reporterId,
            reason: _selectedReason,
            note: _noteController.text,
          );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      if (widget.onSubmitted != null) {
        widget.onSubmitted!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = SpotDetailErrorMapper.map(
          e,
          fallback: 'Không thể gửi báo cáo lúc này. Vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Báo cáo nội dung vi phạm',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chọn lý do phù hợp nhất cho địa điểm "${widget.spotTitle}".',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final reason in SpotReportReason.values) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _selectedReason == reason
                        ? colors.primaryContainer.withValues(alpha: 0.55)
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('report_reason_${reason.code}'),
                      onTap: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedReason = reason;
                                _errorMessage = null;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedReason == reason
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: _selectedReason == reason
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reason.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: _selectedReason == reason
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextField(
                key: const Key('report_note_field'),
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: 'Ghi chú bổ sung (không bắt buộc)',
                  hintText: 'Mô tả ngắn tình trạng thực tế bạn gặp...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('report_error_banner'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('report_submit_button'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Gửi báo cáo',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}