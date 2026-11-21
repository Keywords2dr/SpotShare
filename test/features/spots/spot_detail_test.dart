import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/spots/presentation/detail/spot_detail_support.dart';

class FakeSpotReportGateway implements SpotReportGateway {
  FakeSpotReportGateway({
    this.errorToThrow,
    this.completer,
  });

  Object? errorToThrow;
  Completer<void>? completer;
  final List<
      ({
        String spotId,
        String spotTitle,
        String reporterId,
        SpotReportReason reason,
        String note,
      })> submittedReports = [];

  @override
  Future<void> submitReport({
    required String spotId,
    required String spotTitle,
    required String reporterId,
    required SpotReportReason reason,
    String note = '',
  }) async {
    if (completer != null) {
      await completer!.future;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    submittedReports.add((
      spotId: spotId,
      spotTitle: spotTitle,
      reporterId: reporterId,
      reason: reason,
      note: note.trim(),
    ));
  }
}

void main() {
  group('SpotDetailErrorMapper', () {
    test('maps FirebaseException permission-denied without leaking raw code',
        () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );

      final message = SpotDetailErrorMapper.map(
        error,
        fallback: 'Lỗi mặc định',
      );

      expect(message, contains('chưa có quyền'));
      expect(message, isNot(contains('cloud_firestore')));
    });

    test('maps wrapped string errors and falls back cleanly', () {
      final wrapped = Exception(
        '[cloud_firestore/unavailable] The service is currently unavailable.',
      );
      expect(
        SpotDetailErrorMapper.map(wrapped, fallback: 'Fallback'),
        contains('Mất kết nối mạng'),
      );

      expect(
        SpotDetailErrorMapper.map(Exception('weird'), fallback: 'Fallback'),
        'Fallback',
      );
    });
  });

  group('SpotCoordinatesHelper', () {
    test('rejects (0, 0), NaN, and out-of-range coordinates', () {
      expect(SpotCoordinatesHelper.isValid(0, 0), isFalse);
      expect(SpotCoordinatesHelper.isValid(double.nan, 106.5), isFalse);
      expect(SpotCoordinatesHelper.isValid(95, 106.5), isFalse);
      expect(SpotCoordinatesHelper.isValid(10.76, 185), isFalse);
      expect(SpotCoordinatesHelper.isValid(10.76735, 106.59600), isTrue);
    });

    test('formats coordinates, Maps URL, and share summary', () {
      expect(
        SpotCoordinatesHelper.format(10.76735, 106.596),
        '10.76735, 106.59600',
      );
      expect(
        SpotCoordinatesHelper.googleMapsUrl(10.76735, 106.596),
        'https://www.google.com/maps/search/?api=1&query=10.767350,106.596000',
      );

      final summary = SpotCoordinatesHelper.buildShareSummary(
        title: 'Lâu đài Kyaru',
        category: 'Di tích / Văn hóa',
        addressText: 'Hương Lộ 2, TP.HCM',
        latitude: 10.76735,
        longitude: 106.596,
      );
      expect(summary, contains('Lâu đài Kyaru (Di tích / Văn hóa)'));
      expect(summary, contains('Hương Lộ 2, TP.HCM'));
      expect(summary, contains('google.com/maps/search'));
    });
  });

  group('SpotOptimisticResolver', () {
    test(
        'holds optimistic state during request and prevents flicker before stream catches up',
        () {
      expect(
        SpotOptimisticResolver.resolveBool(
          serverValue: false,
          pendingValue: true,
          isProcessing: true,
        ),
        isTrue,
      );
      expect(
        SpotOptimisticResolver.resolveBool(
          serverValue: false,
          pendingValue: true,
          isProcessing: false,
        ),
        isTrue,
      );
      expect(
        SpotOptimisticResolver.resolveCount(
          serverCount: 0,
          serverActive: false,
          pendingActive: true,
          pendingCount: 1,
          isProcessing: false,
        ),
        1,
      );
      expect(
        SpotOptimisticResolver.resolveCount(
          serverCount: 2,
          serverActive: true,
          pendingActive: true,
          pendingCount: 1,
          isProcessing: false,
        ),
        2,
      );
    });

    test('never computes negative counts', () {
      expect(
        SpotOptimisticResolver.nextCount(currentCount: 0, willBeActive: false),
        0,
      );
      expect(
        SpotOptimisticResolver.nextCount(currentCount: -3, willBeActive: true),
        1,
      );
    });
  });

  group('SpotDetail support widgets', () {
    testWidgets('SpotActionBar renders rating with count and handles taps',
        (tester) async {
      var likeTapped = 0;
      var commentTapped = 0;
      var saveTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotActionBar(
              isLiked: true,
              likesCount: 12,
              isSaved: false,
              ratingAvg: 4.8,
              ratingCount: 5,
              onLikeTap: () => likeTapped++,
              onCommentTap: () => commentTapped++,
              onSaveTap: () => saveTapped++,
            ),
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Lưu'), findsOneWidget);
      expect(find.text('4.8 (5)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_detail_like_button')));
      await tester.tap(find.byKey(const Key('spot_detail_comment_button')));
      await tester.tap(find.byKey(const Key('spot_detail_save_button')));
      await tester.pump();

      expect(likeTapped, 1);
      expect(commentTapped, 1);
      expect(saveTapped, 1);
    });

    testWidgets(
        'SpotCoordinatesCard hides invalid (0,0) coordinates while keeping tags',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotCoordinatesCard(
              tags: const [
                SpotQuickTagData(icon: Icons.wb_sunny_outlined, label: 'Cả ngày'),
              ],
              latitude: 0,
              longitude: 0,
              onCopyCoordinates: () {},
              onCopyMapsLink: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cả ngày'), findsOneWidget);
      expect(find.byKey(const Key('spot_detail_coordinates_text')), findsNothing);
      expect(find.byKey(const Key('spot_detail_copy_coords_button')), findsNothing);
    });

    testWidgets(
        'SpotCoordinatesCard shows copy and Maps link buttons for valid coordinates',
        (tester) async {
      var copiedCoords = false;
      var copiedMaps = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotCoordinatesCard(
              tags: const [
                SpotQuickTagData(icon: Icons.payments_outlined, label: '> 150k'),
              ],
              latitude: 10.76735,
              longitude: 106.596,
              onCopyCoordinates: () => copiedCoords = true,
              onCopyMapsLink: () => copiedMaps = true,
            ),
          ),
        ),
      );

      expect(find.text('Tọa độ: 10.76735, 106.59600'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_detail_copy_coords_button')));
      await tester.tap(find.byKey(const Key('spot_detail_copy_maps_button')));
      await tester.pump();

      expect(copiedCoords, isTrue);
      expect(copiedMaps, isTrue);
    });

    testWidgets(
        'SpotReportSheet prevents duplicate submits and resets spinner after callback',
        (tester) async {
      final completer = Completer<void>();
      final fakeGateway = FakeSpotReportGateway(completer: completer);
      var submitted = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReportGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SpotReportSheet(
                spotId: 'spot_kyaru',
                spotTitle: 'Lâu đài Kyaru',
                reporterId: 'user_2',
                onSubmitted: () => submitted = true,
              ),
            ),
          ),
        ),
      );

      final closedOption =
          find.byKey(const Key('report_reason_permanently_closed'));
      await tester.ensureVisible(closedOption);
      await tester.pumpAndSettle();
      await tester.tap(closedOption);
      await tester.pump();

      final noteField = find.byKey(const Key('report_note_field'));
      await tester.ensureVisible(noteField);
      await tester.pumpAndSettle();
      await tester.enterText(noteField, 'Quán đã đóng cửa từ tháng trước');

      final submitButton = find.byKey(const Key('report_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(submitButton);
      await tester.pump();

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(submitted, isTrue);
      expect(fakeGateway.submittedReports.length, 1);
      expect(
        fakeGateway.submittedReports.first.reason,
        SpotReportReason.permanentlyClosed,
      );
      expect(
        fakeGateway.submittedReports.first.note,
        'Quán đã đóng cửa từ tháng trước',
      );
    });

    testWidgets(
        'SpotReportSheet shows error banner on failure in Dark Mode compact viewport',
        (tester) async {
      final fakeGateway = FakeSpotReportGateway(
        errorToThrow: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotReportGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: const Scaffold(
              body: SpotReportSheet(
                spotId: 'spot_1',
                spotTitle: 'Bãi Xép',
                reporterId: 'user_2',
              ),
            ),
          ),
        ),
      );

      final submitButton = find.byKey(const Key('report_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('report_error_banner')), findsOneWidget);
      expect(find.textContaining('chưa có quyền'), findsOneWidget);
    });

    testWidgets('SpotDetailErrorView triggers retry and back callbacks',
        (tester) async {
      var retried = false;
      var backed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpotDetailErrorView(
              icon: Icons.wifi_off_rounded,
              title: 'Không thể tải địa điểm',
              message: 'Mất kết nối mạng.',
              onRetry: () => retried = true,
              onBack: () => backed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('spot_detail_retry_button')));
      await tester.tap(find.byKey(const Key('spot_detail_back_button')));
      await tester.pump();

      expect(retried, isTrue);
      expect(backed, isTrue);
    });
  });
}