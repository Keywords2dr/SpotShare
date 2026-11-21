import 'package:flutter/material.dart';

enum CompactExploreSortOption {
  recommended('Đề xuất', Icons.local_fire_department_rounded),
  newest('Mới nhất', Icons.schedule_rounded);

  const CompactExploreSortOption(this.label, this.icon);

  final String label;
  final IconData icon;
}

class CompactExploreHeader extends StatefulWidget {
  const CompactExploreHeader({
    super.key,
    this.title = 'Trang chủ',
    this.searchHint = 'Tìm địa điểm, món ăn, @user...',
    this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.selectedSort = CompactExploreSortOption.recommended,
    this.onSortChanged,
    this.activeFilterCount = 0,
    this.onFilterTap,
    this.onMapTap,
    this.showTitleRow = true,
  });

  final String title;
  final String searchHint;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final CompactExploreSortOption selectedSort;
  final ValueChanged<CompactExploreSortOption>? onSortChanged;
  final int activeFilterCount;
  final VoidCallback? onFilterTap;
  final VoidCallback? onMapTap;
  final bool showTitleRow;

  @override
  State<CompactExploreHeader> createState() => _CompactExploreHeaderState();
}

class _CompactExploreHeaderState extends State<CompactExploreHeader> {
  TextEditingController? _internalController;
  bool _hasQuery = false;

  TextEditingController get _controller =>
      widget.searchController ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.searchController == null) {
      _internalController = TextEditingController();
    }
    _hasQuery = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant CompactExploreHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      (oldWidget.searchController ?? _internalController)
          ?.removeListener(_handleTextChange);
      if (widget.searchController == null && _internalController == null) {
        _internalController = TextEditingController();
      }
      _controller.addListener(_handleTextChange);
      _hasQuery = _controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _internalController?.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final nextHasQuery = _controller.text.trim().isNotEmpty;
    if (nextHasQuery != _hasQuery) {
      setState(() => _hasQuery = nextHasQuery);
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onSearchChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('compact_explore_header'),
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTitleRow) ...[
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (widget.onMapTap != null)
                    _CompactHeaderActionChip(
                      key: const Key('explore_header_map_button'),
                      icon: Icons.map_outlined,
                      label: 'Bản đồ',
                      onTap: widget.onMapTap!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.4),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          key: const Key('explore_header_search_field'),
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onChanged: widget.onSearchChanged,
                          onSubmitted: widget.onSearchSubmitted,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            color: colors.onSurface,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: widget.searchHint,
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      if (_hasQuery)
                        IconButton(
                          key: const Key('explore_header_clear_search'),
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: _clearSearch,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              if (widget.onFilterTap != null) ...[
                const SizedBox(width: 8),
                _CompactIconSquareButton(
                  key: const Key('explore_header_filter_button'),
                  tooltip: 'Bộ lọc danh mục, khoảng giá & khung giờ',
                  icon: Icons.tune_rounded,
                  badgeCount: widget.activeFilterCount,
                  isActive: widget.activeFilterCount > 0,
                  onTap: widget.onFilterTap!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Row(
              children: [
                for (final option in CompactExploreSortOption.values) ...[
                  _CompactFilterPill(
                    key: Key('explore_sort_${option.name}'),
                    icon: option.icon,
                    label: option.label,
                    isSelected: widget.selectedSort == option,
                    onTap: widget.onSortChanged == null
                        ? null
                        : () => widget.onSortChanged!(option),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHeaderActionChip extends StatelessWidget {
  const _CompactHeaderActionChip({
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
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colors.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIconSquareButton extends StatelessWidget {
  const _CompactIconSquareButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconWidget = Icon(
      icon,
      size: 18,
      color: isActive ? colors.onPrimaryContainer : colors.onSurfaceVariant,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? colors.primaryContainer.withValues(alpha: 0.85)
            : colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? colors.primary.withValues(alpha: 0.45)
                    : colors.outlineVariant.withValues(alpha: 0.4),
                width: 0.7,
              ),
            ),
            child: badgeCount > 0
                ? Badge(
                    label: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: iconWidget,
                  )
                : iconWidget,
          ),
        ),
      ),
    );
  }
}

class _CompactFilterPill extends StatelessWidget {
  const _CompactFilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? colors.primaryContainer.withValues(alpha: 0.85)
          : colors.surface,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.outlineVariant.withValues(alpha: 0.65),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13.5,
                  color: isSelected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}