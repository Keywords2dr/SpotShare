import 'package:flutter/material.dart';

class CompactNavItemData {
  const CompactNavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
    this.keyName,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;
  final String? keyName;
}

class CompactBottomNavBar extends StatelessWidget {
  const CompactBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 58,
  });

  final List<CompactNavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final safeIndex =
        (currentIndex >= 0 && currentIndex < items.length) ? currentIndex : 0;

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
      child: Material(
        color: colors.surface,
        elevation: 0,
        child: Container(
          key: const Key('compact_bottom_nav_container'),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.45),
                width: 0.6,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _CompactBottomNavItem(
                          key: Key(items[i].keyName ?? 'compact_nav_item_$i'),
                          item: items[i],
                          isSelected: i == safeIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBottomNavItem extends StatelessWidget {
  const _CompactBottomNavItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final CompactNavItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeIconColor = colors.onPrimaryContainer;
    final activeLabelColor = colors.primary;
    final inactiveColor = colors.onSurfaceVariant;

    final iconWidget = Icon(
      isSelected ? item.selectedIcon : item.icon,
      size: 20,
      color: isSelected ? activeIconColor : inactiveColor,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.05),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: isSelected ? 46 : 30,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primaryContainer.withValues(alpha: 0.85)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: item.badgeCount > 0
                    ? Badge(
                        label: Text(
                          item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: iconWidget,
                      )
                    : iconWidget,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  letterSpacing: -0.1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeLabelColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}