import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/spots/data/spot_like_repository.dart';
import 'package:spotshare/features/spots/presentation/like/spot_like_button.dart';
import 'package:spotshare/features/spots/presentation/like/spot_like_controller.dart';

class FakeSpotLikeGateway implements SpotLikeGateway {
  FakeSpotLikeGateway({
    this.errorToThrow,
    this.completer,
    this.initialLiked = false,
    this.initialCount = 0,
  });

  Object? errorToThrow;
  Completer<void>? completer;
  bool initialLiked;
  int initialCount;
  int toggleCalls = 0;

  @override
  Stream<bool> watchIsLiked({
    required String spotId,
    required String userId,
  }) {
    return Stream<bool>.value(initialLiked);
  }

  @override
  Future<SpotLikeResult> toggleLike({
    required String spotId,
    required String userId,
    String? authorId,
  }) async {
    toggleCalls++;
    if (completer != null) {
      await completer!.future;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    final previousCount = initialCount;
    initialLiked = !initialLiked;
    initialCount = SpotLikeLogic.computeNextCount(
      currentCount: previousCount,
      willLike: initialLiked,
    );
    return SpotLikeResult(
      isLiked: initialLiked,
      likesCount: initialCount,
      reachedMilestone: SpotLikeLogic.detectReachedMilestone(
        previousCount: previousCount,
        nextCount: initialCount,
        willLike: initialLiked,
      ),
    );
  }
}

void main() {
  group('SpotLikeLogic & error mapping', () {
    test('parses non-negative integers safely from arbitrary Firestore values',
        () {
      expect(SpotLikeLogic.parseNonNegativeInt(null), 0);
      expect(SpotLikeLogic.parseNonNegativeInt('10'), 0);
      expect(SpotLikeLogic.parseNonNegativeInt(-5), 0);
      expect(SpotLikeLogic.parseNonNegativeInt(12.8), 12);
      expect(SpotLikeLogic.parseNonNegativeInt(7), 7);
    });

    test('detects FR-25 milestones only on upward like transitions', () {
      expect(
        SpotLikeLogic.detectReachedMilestone(
          previousCount: 9,
          nextCount: 10,
          willLike: true,
        ),
        10,
      );
      expect(
        SpotLikeLogic.detectReachedMilestone(
          previousCount: 49,
          nextCount: 50,
          willLike: true,
        ),
        50,
      );
      expect(
        SpotLikeLogic.detectReachedMilestone(
          previousCount: 99,
          nextCount: 100,
          willLike: true,
        ),
        100,
      );
      expect(
        SpotLikeLogic.detectReachedMilestone(
          previousCount: 11,
          nextCount: 10,
          willLike: false,
        ),
        isNull,
      );
      expect(
        SpotLikeLogic.detectReachedMilestone(
          previousCount: 10,
          nextCount: 11,
          willLike: true,
        ),
        isNull,
      );
    });

    test('maps Firebase error codes to Vietnamese messages without raw codes',
        () {
      final denied =
          FirestoreSpotLikeRepository.mapErrorCode('permission-denied');
      expect(denied, contains('chưa được cấp quyền'));
      expect(denied, isNot(contains('permission-denied')));

      final offline = FirestoreSpotLikeRepository.mapErrorCode('unavailable');
      expect(offline, contains('Mất kết nối mạng'));

      final unknown = FirestoreSpotLikeRepository.mapErrorCode('weird-code');
      expect(unknown, contains('Không thể cập nhật lượt thích'));
    });
  });

  group('SpotLikeController unit tests', () {
    test(
        'updates optimistically, blocks concurrent taps, and returns reached milestone',
        () async {
      final completer = Completer<void>();
      final fakeGateway = FakeSpotLikeGateway(
        completer: completer,
        initialLiked: false,
        initialCount: 9,
      );
      final container = ProviderContainer(
        overrides: [
          spotLikeGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(spotLikeControllerProvider.notifier);

      final firstFuture = notifier.toggleLike(
        spotId: 'spot_kyaru',
        userId: 'user_1',
        authorId: 'author_tan',
        fallbackIsLiked: false,
        fallbackLikesCount: 9,
      );

      final optimistic =
          container.read(spotLikeControllerProvider)['spot_kyaru'];
      expect(optimistic?.isLiked, isTrue);
      expect(optimistic?.likesCount, 10);
      expect(optimistic?.isProcessing, isTrue);

      notifier.syncFromServer(
        spotId: 'spot_kyaru',
        isLiked: false,
        likesCount: 9,
      );
      expect(
        container.read(spotLikeControllerProvider)['spot_kyaru']?.isLiked,
        isTrue,
      );

      final duplicateOutcome = await notifier.toggleLike(
        spotId: 'spot_kyaru',
        userId: 'user_1',
        authorId: 'author_tan',
        fallbackIsLiked: false,
        fallbackLikesCount: 9,
      );
      expect(duplicateOutcome.ignored, isTrue);
      expect(fakeGateway.toggleCalls, 1);

      completer.complete();
      final outcome = await firstFuture;
      expect(outcome.success, isTrue);
      expect(outcome.reachedMilestone, 10);

      final committed =
          container.read(spotLikeControllerProvider)['spot_kyaru'];
      expect(committed?.isLiked, isTrue);
      expect(committed?.likesCount, 10);
      expect(committed?.isProcessing, isFalse);

      notifier.clearAll();
      expect(container.read(spotLikeControllerProvider), isEmpty);
    });

    test('rolls back state and returns friendly message on permission-denied',
        () async {
      final fakeGateway = FakeSpotLikeGateway(
        errorToThrow: SpotLikeException(
          FirestoreSpotLikeRepository.mapErrorCode('permission-denied'),
          code: 'permission-denied',
        ),
        initialLiked: false,
        initialCount: 5,
      );
      final container = ProviderContainer(
        overrides: [
          spotLikeGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(spotLikeControllerProvider.notifier);
      final outcome = await notifier.toggleLike(
        spotId: 'spot_kyaru',
        userId: 'user_1',
        fallbackIsLiked: false,
        fallbackLikesCount: 5,
      );

      expect(outcome.success, isFalse);
      expect(outcome.errorMessage, contains('chưa được cấp quyền'));
      expect(outcome.errorMessage, isNot(contains('cloud_firestore/')));

      final rolledBack =
          container.read(spotLikeControllerProvider)['spot_kyaru'];
      expect(rolledBack?.isLiked, isFalse);
      expect(rolledBack?.likesCount, 5);
      expect(rolledBack?.isProcessing, isFalse);
    });

    test('never drops likesCount below zero when unliking a 0-count spot',
        () async {
      final fakeGateway = FakeSpotLikeGateway(
        initialLiked: true,
        initialCount: 0,
      );
      final container = ProviderContainer(
        overrides: [
          spotLikeGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(spotLikeControllerProvider.notifier);
      final outcome = await notifier.toggleLike(
        spotId: 'spot_zero',
        userId: 'user_1',
        fallbackIsLiked: true,
        fallbackLikesCount: 0,
      );

      expect(outcome.success, isTrue);
      final state = container.read(spotLikeControllerProvider)['spot_zero'];
      expect(state?.isLiked, isFalse);
      expect(state?.likesCount, 0);
    });
  });

  group('SpotLikeButton widget tests', () {
    testWidgets('toggles like count and icon on tap and rolls back on failure',
        (tester) async {
      final fakeGateway = FakeSpotLikeGateway(
        initialLiked: false,
        initialCount: 0,
      );
      String? capturedError;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotLikeGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SpotLikeButton(
                spotId: 'spot_1',
                authorId: 'author_tan',
                userId: 'user_1',
                initialLikesCount: 0,
                initialIsLiked: false,
                onError: (msg) => capturedError = msg,
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('spot_like_button_spot_1')));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      fakeGateway.errorToThrow = SpotLikeException(
        FirestoreSpotLikeRepository.mapErrorCode('unavailable'),
        code: 'unavailable',
      );

      await tester.tap(find.byKey(const Key('spot_like_button_spot_1')));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(capturedError, contains('Mất kết nối mạng'));
    });

    testWidgets(
        'prompts login for guest user without calling gateway in Dark Mode',
        (tester) async {
      final fakeGateway = FakeSpotLikeGateway();
      var loginPrompted = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spotLikeGatewayProvider.overrideWithValue(fakeGateway),
          ],
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SpotLikeButton(
                spotId: 'spot_guest',
                userId: null,
                initialLikesCount: 3,
                initialIsLiked: false,
                onRequireLogin: () => loginPrompted = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('spot_like_button_spot_guest')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(loginPrompted, isTrue);
      expect(fakeGateway.toggleCalls, 0);
      expect(find.text('3'), findsOneWidget);
    });
  });
}