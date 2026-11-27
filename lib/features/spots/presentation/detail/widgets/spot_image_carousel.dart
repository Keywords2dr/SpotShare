import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef SpotCarouselImageBuilder = Widget Function(
  BuildContext context,
  String url,
  BoxFit fit,
);

class SpotImageUrlHelper {
  static List<String> sanitizeUrls(List<String> rawUrls) {
    return rawUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static String detailUrl(String rawUrl) {
    return _applyCloudinaryTransform(rawUrl, 'f_auto,q_auto,w_1400');
  }

  static String thumbnailUrl(String rawUrl) {
    return _applyCloudinaryTransform(rawUrl, 'f_auto,q_auto,w_600');
  }

  static String _applyCloudinaryTransform(String rawUrl, String transform) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';
    const marker = '/image/upload/';
    final markerIndex = clean.indexOf(marker);
    if (!clean.contains('res.cloudinary.com') || markerIndex == -1) {
      return clean;
    }

    final afterMarker = clean.substring(markerIndex + marker.length);
    if (afterMarker.startsWith('f_auto') ||
        afterMarker.startsWith('q_auto') ||
        afterMarker.startsWith('w_') ||
        afterMarker.startsWith('c_')) {
      return clean;
    }

    final prefix = clean.substring(0, markerIndex + marker.length);
    return '$prefix$transform/$afterMarker';
  }
}

class _GalleryScrollBehavior extends MaterialScrollBehavior {
  const _GalleryScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class SpotImageCarousel extends StatefulWidget {
  const SpotImageCarousel({
    super.key,
    required this.images,
    this.aspectRatio = 4 / 3,
    this.maxHeight = 420,
    this.imageBuilder,
  });

  final List<String> images;
  final double aspectRatio;
  final double? maxHeight;
  final SpotCarouselImageBuilder? imageBuilder;

  @override
  State<SpotImageCarousel> createState() => _SpotImageCarouselState();
}

class _SpotImageCarouselState extends State<SpotImageCarousel> {
  static const double _dotsReservedHeight = 16.0;

  late final PageController _pageController;
  int _currentIndex = 0;

  List<String> get _cleanImages => SpotImageUrlHelper.sanitizeUrls(widget.images);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant SpotImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final length = _cleanImages.length;
    if (length == 0) {
      _currentIndex = 0;
    } else if (_currentIndex >= length) {
      _currentIndex = length - 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    final length = _cleanImages.length;
    if (index < 0 || index >= length || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openFullscreen(int initialIndex) async {
    final urls = _cleanImages;
    if (urls.isEmpty) return;

    final lastViewedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => FullscreenImageGallery(
          images: urls,
          initialIndex: initialIndex,
          imageBuilder: widget.imageBuilder,
        ),
      ),
    );

    if (lastViewedIndex != null &&
        mounted &&
        lastViewedIndex >= 0 &&
        lastViewedIndex < urls.length &&
        lastViewedIndex != _currentIndex) {
      setState(() => _currentIndex = lastViewedIndex);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(lastViewedIndex);
      }
    }
  }

  double _resolveImageHeight(
    BuildContext context,
    BoxConstraints constraints,
    bool showDots,
  ) {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    double height = maxWidth / widget.aspectRatio;
    if (widget.maxHeight != null && height > widget.maxHeight!) {
      height = widget.maxHeight!;
    }
    if (constraints.maxHeight.isFinite) {
      final reserved = showDots ? _dotsReservedHeight : 0.0;
      final available = constraints.maxHeight - reserved;
      if (available <= 0) {
        return 0;
      }
      if (height > available) {
        height = available;
      }
    }
    return height < 0 ? 0 : height;
  }

  Widget _buildImage(BuildContext context, String rawUrl) {
    final optimizedUrl = SpotImageUrlHelper.detailUrl(rawUrl);
    if (widget.imageBuilder != null) {
      return widget.imageBuilder!(context, optimizedUrl, BoxFit.cover);
    }

    final colors = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: 36,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _cleanImages;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (urls.isEmpty) {
          final emptyHeight = _resolveImageHeight(context, constraints, false);
          return SizedBox(
            width: double.infinity,
            height: emptyHeight,
            child: Container(
              key: const Key('spot_carousel_empty'),
              color: colors.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.landscape_outlined,
                size: 40,
                color: colors.onSurfaceVariant,
              ),
            ),
          );
        }

        final showDots = urls.length > 1;
        final imageHeight = _resolveImageHeight(context, constraints, showDots);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ScrollConfiguration(
                    behavior: const _GalleryScrollBehavior(),
                    child: PageView.builder(
                      key: const Key('spot_carousel_page_view'),
                      controller: _pageController,
                      itemCount: urls.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          key: Key('spot_carousel_image_$index'),
                          onTap: () => _openFullscreen(index),
                          child: _buildImage(context, urls[index]),
                        );
                      },
                    ),
                  ),
                  if (showDots)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('spot_carousel_counter'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showDots && _currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _OverlayCircleButton(
                          key: const Key('spot_carousel_prev_button'),
                          tooltip: 'Ảnh trước',
                          icon: Icons.chevron_left_rounded,
                          onTap: () => _goToPage(_currentIndex - 1),
                        ),
                      ),
                    ),
                  if (showDots && _currentIndex < urls.length - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _OverlayCircleButton(
                          key: const Key('spot_carousel_next_button'),
                          tooltip: 'Ảnh tiếp theo',
                          icon: Icons.chevron_right_rounded,
                          onTap: () => _goToPage(_currentIndex + 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showDots)
              SizedBox(
                height: _dotsReservedHeight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < urls.length; i++)
                        GestureDetector(
                          key: Key('spot_carousel_dot_$i'),
                          onTap: () => _goToPage(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentIndex
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FullscreenImageGallery extends StatefulWidget {
  const FullscreenImageGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.imageBuilder,
  });

  final List<String> images;
  final int initialIndex;
  final SpotCarouselImageBuilder? imageBuilder;

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late final List<String> _images;
  late final PageController _pageController;
  final FocusNode _keyboardFocusNode = FocusNode();
  int _currentIndex = 0;
  bool _isCurrentPageZoomed = false;
  double _verticalDragOffset = 0;
  int _zoomResetSeed = 0;

  @override
  void initState() {
    super.initState();
    _images = SpotImageUrlHelper.sanitizeUrls(widget.images);
    final safeInitial = _images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _images.length - 1);
    _currentIndex = safeInitial;
    _pageController = PageController(initialPage: safeInitial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).maybePop(_currentIndex);
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _images.length || !_pageController.hasClients) {
      return;
    }
    setState(() {
      _isCurrentPageZoomed = false;
      _zoomResetSeed++;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetZoom() {
    if (!_isCurrentPageZoomed) return;
    setState(() {
      _isCurrentPageZoomed = false;
      _zoomResetSeed++;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isCurrentPageZoomed) return;
    setState(() {
      _verticalDragOffset =
          (_verticalDragOffset + details.delta.dy).clamp(0.0, 260.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isCurrentPageZoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_verticalDragOffset > 90 || velocity > 500) {
      _close();
      return;
    }
    if (_verticalDragOffset != 0) {
      setState(() => _verticalDragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundAlpha =
        (1.0 - (_verticalDragOffset / 320.0)).clamp(0.45, 1.0);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!_isCurrentPageZoomed && _currentIndex > 0) {
            _goToPage(_currentIndex - 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!_isCurrentPageZoomed && _currentIndex < _images.length - 1) {
            _goToPage(_currentIndex + 1);
          }
        },
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: backgroundAlpha),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_images.isEmpty)
                const Center(
                  child: Text(
                    'Không có hình ảnh để hiển thị',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              else
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate:
                      _isCurrentPageZoomed ? null : _onVerticalDragUpdate,
                  onVerticalDragEnd:
                      _isCurrentPageZoomed ? null : _onVerticalDragEnd,
                  child: Transform.translate(
                    offset: Offset(0, _verticalDragOffset),
                    child: ScrollConfiguration(
                      behavior: const _GalleryScrollBehavior(),
                      child: PageView.builder(
                        key: const Key('fullscreen_gallery_page_view'),
                        controller: _pageController,
                        physics: _isCurrentPageZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: _images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                            _isCurrentPageZoomed = false;
                          });
                        },
                        itemBuilder: (context, index) {
                          return _ZoomableGalleryPage(
                            key: ValueKey('gallery_page_${index}_$_zoomResetSeed'),
                            imageUrl: SpotImageUrlHelper.detailUrl(_images[index]),
                            imageBuilder: widget.imageBuilder,
                            onZoomChanged: (zoomed) {
                              if (index == _currentIndex &&
                                  _isCurrentPageZoomed != zoomed) {
                                setState(() => _isCurrentPageZoomed = zoomed);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _OverlayCircleButton(
                            key: const Key('fullscreen_gallery_back_button'),
                            tooltip: 'Quay lại',
                            icon: Icons.arrow_back_rounded,
                            size: 40,
                            iconSize: 22,
                            onTap: _close,
                          ),
                          const Spacer(),
                          if (_images.isNotEmpty)
                            Container(
                              key: const Key('fullscreen_gallery_counter'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${_currentIndex + 1} / ${_images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_images.length > 1 && !_isCurrentPageZoomed && _currentIndex > 0)
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _OverlayCircleButton(
                      key: const Key('fullscreen_gallery_prev_button'),
                      tooltip: 'Ảnh trước',
                      icon: Icons.chevron_left_rounded,
                      size: 42,
                      iconSize: 26,
                      onTap: () => _goToPage(_currentIndex - 1),
                    ),
                  ),
                ),
              if (_images.length > 1 &&
                  !_isCurrentPageZoomed &&
                  _currentIndex < _images.length - 1)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _OverlayCircleButton(
                      key: const Key('fullscreen_gallery_next_button'),
                      tooltip: 'Ảnh tiếp theo',
                      icon: Icons.chevron_right_rounded,
                      size: 42,
                      iconSize: 26,
                      onTap: () => _goToPage(_currentIndex + 1),
                    ),
                  ),
                ),
              if (_images.length > 1 || _isCurrentPageZoomed)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.78),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isCurrentPageZoomed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton.icon(
                                  key: const Key(
                                    'fullscreen_gallery_reset_zoom_button',
                                  ),
                                  onPressed: _resetZoom,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.6),
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.zoom_out_map_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Đặt lại 1x',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (_images.length > 1)
                              SizedBox(
                                height: 54,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  shrinkWrap: true,
                                  itemCount: _images.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final selected = index == _currentIndex;
                                    final thumbUrl =
                                        SpotImageUrlHelper.thumbnailUrl(
                                      _images[index],
                                    );
                                    return GestureDetector(
                                      key: Key('fullscreen_gallery_thumb_$index'),
                                      onTap: () => _goToPage(index),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selected
                                                ? Colors.white
                                                : Colors.white
                                                    .withValues(alpha: 0.25),
                                            width: selected ? 2.2 : 1,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Opacity(
                                          opacity: selected ? 1.0 : 0.62,
                                          child: widget.imageBuilder != null
                                              ? widget.imageBuilder!(
                                                  context,
                                                  thumbUrl,
                                                  BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: thumbUrl,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, _, _) =>
                                                      const ColoredBox(
                                                    color: Color(0xFF222222),
                                                    child: Icon(
                                                      Icons.image_outlined,
                                                      color: Colors.white54,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableGalleryPage extends StatefulWidget {
  const _ZoomableGalleryPage({
    super.key,
    required this.imageUrl,
    required this.onZoomChanged,
    this.imageBuilder,
  });

  final String imageUrl;
  final ValueChanged<bool> onZoomChanged;
  final SpotCarouselImageBuilder? imageBuilder;

  @override
  State<_ZoomableGalleryPage> createState() => _ZoomableGalleryPageState();
}

class _ZoomableGalleryPageState extends State<_ZoomableGalleryPage> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final nextZoomed = scale > 1.02;
    if (nextZoomed != _isZoomed) {
      setState(() => _isZoomed = nextZoomed);
      widget.onZoomChanged(nextZoomed);
    }
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      _syncZoomState();
      return;
    }

    const scale = 2.5;
    final tapPos = _doubleTapDetails?.localPosition ?? Offset.zero;
    final zoomed = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, -tapPos.dx * (scale - 1))
      ..setEntry(1, 3, -tapPos.dy * (scale - 1));
    _transformationController.value = zoomed;
    _syncZoomState();
  }

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget = widget.imageBuilder != null
        ? widget.imageBuilder!(context, widget.imageUrl, BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
            errorWidget: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 48,
              ),
            ),
          );

    return GestureDetector(
      key: const Key('fullscreen_zoomable_detector'),
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          panEnabled: _isZoomed,
          scaleEnabled: true,
          onInteractionUpdate: (_) => _syncZoomState(),
          onInteractionEnd: (_) {
            if (_transformationController.value.getMaxScaleOnAxis() <= 1.02) {
              _transformationController.value = Matrix4.identity();
            }
            _syncZoomState();
          },
          child: SizedBox.expand(
            child: imageWidget,
          ),
        ),
      ),
    );
  }
}

class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 22,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}