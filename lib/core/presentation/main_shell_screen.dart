import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/notifications_controller.dart';
import 'widgets/compact_bottom_nav_bar.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({
    super.key,
    required this.navigationShell,
    this.unreadNotificationsCount,
  });

  final StatefulNavigationShell navigationShell;
  final int? unreadNotificationsCount;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int badgeCount =
        unreadNotificationsCount ?? ref.watch(unreadNotificationsCountProvider);

    final items = [
      const CompactNavItemData(
        keyName: 'nav_explore',
        label: 'Trang chủ',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      const CompactNavItemData(
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
        badgeCount: badgeCount,
      ),
      const CompactNavItemData(
        keyName: 'nav_profile',
        label: 'Cá nhân',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CompactBottomNavBar(
        items: items,
        currentIndex: navigationShell.currentIndex,
        onTap: _onDestinationSelected,
      ),
    );
  }
}

class TabPlaceholderScreen extends StatelessWidget {
  const TabPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}