import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/features/profile/presentation/widgets/profile_screen_support.dart';

void main() {
  group('ProfileDataParser unit tests', () {
    test('parses complete Firestore profile and prefers liveSpotsCount', () {
      final profile = ProfileDataParser.parse(
        data: const {
          'displayName': '  Teo Em  ',
          'email': 'teoem@qnu.edu.vn',
          'username': 'TeoEm20_73',
          'avatarUrl': 'https://res.cloudinary.com/demo/image/upload/v1/a.jpg',
          'bio': '  Mê biển Quy Nhơn  ',
          'spotsCount': 2,
          'followingCount': 5,
          'followersCount': 1200,
          'totalLikes': 42,
        },
        uid: 'uid_123456789',
        liveSpotsCount: 6,
        formatAvatarUrl: (url) => '$url?thumb=1',
      );

      expect(profile.displayName, 'Teo Em');
      expect(profile.username, 'teoem20_73');
      expect(profile.handle, '@teoem20_73');
      expect(profile.avatarUrl, endsWith('?thumb=1'));
      expect(profile.bio, 'Mê biển Quy Nhơn');
      expect(profile.spotsCount, 6);
      expect(profile.followingCount, 5);
      expect(profile.followersCount, 1200);
      expect(profile.totalLikes, 42);
    });

    test('handles empty Firestore map, short UID, and negative numbers safely',
        () {
      final profile = ProfileDataParser.parse(
        data: const {
          'spotsCount': -4,
          'followingCount': -1,
          'followersCount': -9,
          'totalLikes': -3,
        },
        uid: 'u1',
        authDisplayName: '',
        authEmail: '',
      );

      expect(profile.displayName, 'Thành viên SpotShare');
      expect(profile.username, 'u1');
      expect(profile.handle, '@u1');
      expect(profile.spotsCount, 0);
      expect(profile.followingCount, 0);
      expect(profile.followersCount, 0);
      expect(profile.totalLikes, 0);
    });

    test('formats compact counters accurately across ranges', () {
      expect(ProfileDataParser.formatCompactCount(-10), '0');
      expect(ProfileDataParser.formatCompactCount(0), '0');
      expect(ProfileDataParser.formatCompactCount(999), '999');
      expect(ProfileDataParser.formatCompactCount(1000), '1K');
      expect(ProfileDataParser.formatCompactCount(1250), '1.2K');
      expect(ProfileDataParser.formatCompactCount(100500), '100K');
      expect(ProfileDataParser.formatCompactCount(1500000), '1.5M');
      expect(ProfileDataParser.avatarInitial('  teo em'), 'T');
      expect(ProfileDataParser.avatarInitial('   '), 'S');
    });
  });

  group('ProfileErrorMapper unit tests', () {
    test('maps Firebase and Platform errors into friendly Vietnamese messages',
        () {
      final denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final mappedDenied = ProfileErrorMapper.map(denied, fallback: 'Fallback');
      expect(mappedDenied, contains('chưa có quyền'));
      expect(mappedDenied, isNot(contains('cloud_firestore')));

      final cameraDenied = PlatformException(code: 'camera_access_denied');
      expect(
        ProfileErrorMapper.map(cameraDenied, fallback: 'Fallback'),
        contains('Camera'),
      );

      final photoDenied = PlatformException(code: 'photo_access_denied');
      expect(
        ProfileErrorMapper.map(photoDenied, fallback: 'Fallback'),
        contains('Thư viện ảnh'),
      );

      expect(
        ProfileErrorMapper.map(Exception('other'), fallback: 'Lỗi dự phòng'),
        'Lỗi dự phòng',
      );
    });
  });

  group('Profile support widget tests', () {
    testWidgets(
        'ProfileHeaderSection displays all 4 stats, error banner, and handles callbacks',
        (tester) async {
      var copied = false;
      var edited = false;
      var pickedAvatar = false;
      var retried = false;

      const profile = ProfileSummaryData(
        displayName: 'Teo Em',
        email: 'teoem@gmail.com',
        username: 'teoem20_73',
        handle: '@teoem20_73',
        avatarUrl: '',
        bio: '',
        spotsCount: 8,
        followingCount: 12,
        followersCount: 1250,
        totalLikes: 340,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileHeaderSection(
                profile: profile,
                isUploadingAvatar: false,
                errorMessage: 'Mất kết nối mạng.',
                onRetry: () => retried = true,
                onCopyHandle: () => copied = true,
                onEditProfile: () => edited = true,
                onPickAvatar: () => pickedAvatar = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Teo Em'), findsOneWidget);
      expect(find.text('@teoem20_73'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Bài đăng'), findsOneWidget);
      expect(find.text('1.2K'), findsOneWidget);
      expect(find.text('Follower'), findsOneWidget);
      expect(find.byKey(const Key('profile_error_banner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_retry_button')));
      await tester.tap(find.byKey(const Key('profile_copy_handle_button')));
      await tester.tap(find.byKey(const Key('profile_add_bio_button')));
      await tester.tap(find.byKey(const Key('profile_avatar_button')));
      await tester.pump();

      expect(retried, isTrue);
      expect(copied, isTrue);
      expect(edited, isTrue);
      expect(pickedAvatar, isTrue);
    });

    testWidgets(
        'ProfileHeaderSection disables avatar tap during upload and renders cleanly in Dark Mode 5.5 inch viewport',
        (tester) async {
      var avatarTapped = false;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const profile = ProfileSummaryData(
        displayName: 'Nguyễn Minh Quân Rất Dài Để Test Tràn Khung',
        email: 'quan@qnu.edu.vn',
        username: 'minhquan_quynhon',
        handle: '@minhquan_quynhon',
        avatarUrl: '',
        bio: 'Săn bình minh Kỳ Co & ẩm thực đường phố Quy Nhơn.',
        spotsCount: 120,
        followingCount: 99,
        followersCount: 15400,
        totalLikes: 88200,
      );

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ProfileHeaderSection(
                  profile: profile,
                  isUploadingAvatar: true,
                  onCopyHandle: () {},
                  onEditProfile: () {},
                  onPickAvatar: () => avatarTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_avatar_button')));
      await tester.pump();
      expect(avatarTapped, isFalse);
    });

    testWidgets('ProfileAvatarPickerSheet returns selected source option',
        (tester) async {
      ProfileAvatarSourceOption? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<ProfileAvatarSourceOption>(
                      context: context,
                      builder: (_) => const ProfileAvatarPickerSheet(
                        showCameraOption: true,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatar_source_gallery')), findsOneWidget);
      expect(find.byKey(const Key('avatar_source_camera')), findsOneWidget);

      await tester.tap(find.byKey(const Key('avatar_source_camera')));
      await tester.pumpAndSettle();

      expect(result, ProfileAvatarSourceOption.camera);
    });

    testWidgets('ProfileSignOutDialog returns confirmation boolean and ProfileGuestView triggers login',
        (tester) async {
      bool? confirmed;
      var loginTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => const ProfileSignOutDialog(),
                      );
                    },
                    child: const Text('SignOut'),
                  ),
                  Expanded(
                    child: ProfileGuestView(
                      onLoginTap: () => loginTapped = true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('profile_guest_login_button')));
      await tester.pump();
      expect(loginTapped, isTrue);

      await tester.tap(find.text('SignOut'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign_out_confirm_button')));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });
}