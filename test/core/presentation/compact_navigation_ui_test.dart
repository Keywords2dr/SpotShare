import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotshare/core/presentation/widgets/compact_bottom_nav_bar.dart';
import 'package:spotshare/core/theme/compact_ui_theme.dart';
import 'package:spotshare/features/explore/presentation/widgets/compact_explore_header.dart';

void main() {
  group('CompactUiTheme unit tests', () {
    test(
        'configures compact typography and navigation dimensions for light and dark themes',
        () {
      final light = CompactUiTheme.light();
      final dark = CompactUiTheme.dark();

      expect(light.appBarTheme.toolbarHeight, 48);
      expect(light.navigationBarTheme.height, 58);
      expect(light.textTheme.titleLarge?.fontSize, 17);
      expect(light.textTheme.bodyMedium?.fontSize, 13);
      expect(light.textTheme.labelSmall?.fontSize, 10.5);

      expect(dark.brightness, Brightness.dark);
      expect(dark.appBarTheme.toolbarHeight, 48);
      expect(dark.navigationBarTheme.height, 58);
    });
  });

  group('CompactBottomNavBar widget tests', () {
    testWidgets(
        'switches tabs, displays unread badge, and keeps compact height without overflow',
        (tester) async {
      var selectedIndex = 0;

      const items = [
        CompactNavItemData(
          keyName: 'nav_explore',
          label: 'Trang chủ',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        CompactNavItemData(
          keyName: 'nav_create',
          label: 'Đăng bài',
          icon: Icons.add_circle_outline_rounded,
          selectedIcon: Icons.add_circle_rounded,
        ),
        CompactNavItemData(
          keyName: 'nav_notifications',
          label: 'Hộp thư',
          icon: Icons.mail_outline_rounded,
          selectedIcon: Icons.mail_rounded,
          badgeCount: 12,
        ),
        CompactNavItemData(
          keyName: 'nav_profile',
          label: 'Cá nhân',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: CompactBottomNavBar(
                items: items,
                currentIndex: selectedIndex,
                onTap: (index) => setState(() => selectedIndex = index),
              ),
            ),
          ),
        ),
      );

      final barSize =
          tester.getSize(find.byKey(const Key('compact_bottom_nav_container')));
      expect(barSize.height, lessThanOrEqualTo(60));
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_profile')));
      await tester.pumpAndSettle();

      expect(selectedIndex, 3);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets(
        'renders cleanly on compact 5.5 inch viewport with 1.3x text scaling in Dark Mode',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const items = [
        CompactNavItemData(
          label: 'Trang chủ',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        CompactNavItemData(
          label: 'Đăng bài',
          icon: Icons.add_circle_outline_rounded,
          selectedIcon: Icons.add_circle_rounded,
        ),
        CompactNavItemData(
          label: 'Hộp thư',
          icon: Icons.mail_outline_rounded,
          selectedIcon: Icons.mail_rounded,
          badgeCount: 120,
        ),
        CompactNavItemData(
          label: 'Cá nhân',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: CompactUiTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: CompactBottomNavBar(
                items: items,
                currentIndex: 2,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('CompactExploreHeader widget tests', () {
    testWidgets(
        'shows only sort pills without category clutter and handles search, filter, and map actions',
        (tester) async {
      String latestQuery = '';
      CompactExploreSortOption selectedSort =
          CompactExploreSortOption.recommended;
      var mapTapped = false;
      var filterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompactUiTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    CompactExploreHeader(
                      title: 'Trang chủ',
                      selectedSort: selectedSort,
                      activeFilterCount: 3,
                      onSearchChanged: (value) => latestQuery = value,
                      onSortChanged: (value) =>
                          setState(() => selectedSort = value),
                      onMapTap: () => mapTapped = true,
                      onFilterTap: () => filterTapped = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final headerSize =
          tester.getSize(find.byKey(const Key('compact_explore_header')));
      expect(headerSize.height, lessThanOrEqualTo(132));
      expect(find.text('Đề xuất'), findsOneWidget);
      expect(find.text('Mới nhất'), findsOneWidget);
      expect(find.text('Tất cả'), findsNothing);
      expect(find.text('Bãi biển'), findsNothing);
      expect(find.text('3'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('explore_header_search_field')),
        'Kỳ Co',
      );
      await tester.pump();
      expect(latestQuery, 'Kỳ Co');
      expect(
        find.byKey(const Key('explore_header_clear_search')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('explore_header_clear_search')));
      await tester.pump();
      expect(latestQuery, '');
      expect(
        find.byKey(const Key('explore_header_clear_search')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('explore_sort_newest')));
      await tester.pump();
      expect(selectedSort, CompactExploreSortOption.newest);

      await tester.tap(find.byKey(const Key('explore_header_map_button')));
      await tester.tap(find.byKey(const Key('explore_header_filter_button')));
      await tester.pump();
      expect(mapTapped, isTrue);
      expect(filterTapped, isTrue);
    });

    testWidgets(
        'renders cleanly in Dark Mode on compact 5.5 inch viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: CompactUiTheme.dark(),
          home: Scaffold(
            body: SafeArea(
              child: CompactExploreHeader(
                onSortChanged: (_) {},
                onFilterTap: () {},
                onMapTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}