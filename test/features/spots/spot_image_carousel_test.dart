import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/spots/presentation/detail/widgets/spot_image_carousel.dart';

Widget _fakeImageBuilder(BuildContext context, String url, BoxFit fit) {
  return Container(
    color: Colors.teal.shade800,
    alignment: Alignment.center,
    child: Text(
      url,
      style: const TextStyle(color: Colors.white),
    ),
  );
}

void main() {
  group('SpotImageUrlHelper unit tests', () {
    test('sanitizes empty URLs and applies Cloudinary transformations per SRS 5.2',
        () {
      expect(
        SpotImageUrlHelper.sanitizeUrls([
          '  ',
          'https://a.jpg',
          '',
          ' https://b.jpg ',
        ]),
        ['https://a.jpg', 'https://b.jpg'],
      );

      const rawCloudinary =
          'https://res.cloudinary.com/demo/image/upload/v1700/spot.jpg';
      expect(
        SpotImageUrlHelper.detailUrl(rawCloudinary),
        'https://res.cloudinary.com/demo/image/upload/f_auto,q_auto,w_1400/v1700/spot.jpg',
      );
      expect(
        SpotImageUrlHelper.thumbnailUrl(rawCloudinary),
        'https://res.cloudinary.com/demo/image/upload/f_auto,q_auto,w_600/v1700/spot.jpg',
      );

      const alreadyTransformed =
          'https://res.cloudinary.com/demo/image/upload/f_auto,q_auto,w_600/v1700/spot.jpg';
      expect(
        SpotImageUrlHelper.detailUrl(alreadyTransformed),
        alreadyTransformed,
      );

      const externalUrl = 'https://example.com/photo.jpg';
      expect(SpotImageUrlHelper.detailUrl(externalUrl), externalUrl);
    });
  });

  group('SpotImageCarousel & FullscreenImageGallery widget tests', () {
    const sampleUrls = [
      'https://example.com/photo_1.jpg',
      'https://example.com/photo_2.jpg',
      'https://example.com/photo_3.jpg',
    ];

    testWidgets(
        'switches images inline, opens fullscreen at current page, navigates all images, and exits via close button without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: const Scaffold(
            body: SpotImageCarousel(
              images: sampleUrls,
              imageBuilder: _fakeImageBuilder,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_carousel_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_carousel_image_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('fullscreen_gallery_counter')),
          matching: find.text('2 / 3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('fullscreen_gallery_next_button')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('fullscreen_gallery_counter')),
          matching: find.text('3 / 3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('fullscreen_gallery_thumb_0')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('fullscreen_gallery_counter')),
          matching: find.text('1 / 3'),
        ),
        findsOneWidget,
      );

      await tester.fling(
        find.byKey(const Key('fullscreen_gallery_page_view')),
        const Offset(-300, 0),
        900,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('fullscreen_gallery_counter')),
          matching: find.text('2 / 3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('fullscreen_gallery_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsNothing);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'fits cleanly inside tightly height-constrained container and empty state without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 200,
                child: SpotImageCarousel(
                  images: sampleUrls,
                  imageBuilder: _fakeImageBuilder,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('spot_carousel_dot_0')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 180,
                child: SpotImageCarousel(
                  images: [],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('spot_carousel_empty')), findsOneWidget);
    });

    testWidgets(
        'supports double-tap zoom, reset 1x, keyboard Escape, and swipe-down dismiss in Light Mode on compact viewport',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: const Scaffold(
            body: SpotImageCarousel(
              images: sampleUrls,
              imageBuilder: _fakeImageBuilder,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('spot_carousel_expand_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsOneWidget);

      final detector = find.byKey(const Key('fullscreen_zoomable_detector'));
      final center = tester.getCenter(detector);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('fullscreen_gallery_reset_zoom_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('fullscreen_gallery_reset_zoom_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('fullscreen_gallery_reset_zoom_button')),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('fullscreen_gallery_counter')),
          matching: find.text('2 / 3'),
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsNothing);

      await tester.tap(find.byKey(const Key('spot_carousel_expand_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsOneWidget);

      await tester.fling(
        find.byKey(const Key('fullscreen_gallery_page_view')),
        const Offset(0, 220),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_gallery_page_view')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}