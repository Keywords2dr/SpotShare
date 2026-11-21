import 'package:flutter/material.dart';

import '../../domain/spot_tag_presets.dart';

IconData transportIconFor(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('xe máy') || lower.contains('mô tô')) {
    return Icons.two_wheeler_outlined;
  }
  if (lower.contains('ô tô') || lower.contains('oto')) {
    return Icons.directions_car_outlined;
  }
  if (lower.contains('đi bộ') || lower.contains('trekking')) {
    return Icons.directions_walk_rounded;
  }
  if (lower.contains('cano') ||
      lower.contains('thuyền') ||
      lower.contains('tàu')) {
    return Icons.directions_boat_outlined;
  }
  if (lower.contains('xe đạp')) {
    return Icons.pedal_bike_outlined;
  }
  if (lower.contains('taxi') || lower.contains('công nghệ')) {
    return Icons.local_taxi_outlined;
  }
  if (lower.contains('buýt') || lower.contains('bus')) {
    return Icons.directions_bus_outlined;
  }
  return Icons.commute_outlined;
}

class _DangerHighlightButton extends StatelessWidget {
  const _DangerHighlightButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer.withValues(alpha: 0.65),
      shape: StadiumBorder(
        side: BorderSide(
          color: colors.error.withValues(alpha: 0.45),
          width: 0.9,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 13.5, color: colors.error),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpotCategorySelector extends StatelessWidget {
  const SpotCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.enabled,
    required this.onChanged,
  });

  final String selectedCategory;
  final bool enabled;
  final ValueChanged<String> onChanged;

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Bãi biển':
        return Icons.beach_access_outlined;
      case 'Cảnh đẹp / Check-in':
        return Icons.landscape_outlined;
      case 'Món ăn ngon':
        return Icons.restaurant_outlined;
      case 'Quán cà phê view đẹp':
        return Icons.local_cafe_outlined;
      case 'Cắm trại / Chill':
        return Icons.forest_outlined;
      case 'Di tích / Văn hóa':
        return Icons.account_balance_outlined;
      default:
        return Icons.label_outline_rounded;
    }
  }

  Future<void> _showCustomCategoryDialog(BuildContext context) async {
    final isCustom = selectedCategory.isNotEmpty &&
        !SpotTagPresets.defaultCategories.contains(selectedCategory);
    final result = await _showCustomTagDialog(
      context: context,
      title: 'Danh mục tùy chỉnh',
      initialValue: isCustom ? selectedCategory : '',
      hintText: 'VD: Làng chài, Chợ đêm, Homestay...',
      maxLength: 30,
    );
    if (result != null && result.isNotEmpty) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasCustomCategory = selectedCategory.isNotEmpty &&
        !SpotTagPresets.defaultCategories.contains(selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                text: 'Danh mục ',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Chọn hoặc tự nhập',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in SpotTagPresets.defaultCategories)
              ChoiceChip(
                avatar: Icon(
                  _iconForCategory(category),
                  size: 16,
                  color: selectedCategory == category
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: enabled ? (_) => onChanged(category) : null,
              ),
            if (hasCustomCategory)
              ChoiceChip(
                avatar: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: colors.onSecondaryContainer,
                ),
                label: Text(selectedCategory),
                selected: true,
                onSelected: enabled
                    ? (_) => _showCustomCategoryDialog(context)
                    : null,
              ),
            ActionChip(
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.45),
              side: BorderSide(
                color: colors.primary.withValues(alpha: 0.45),
              ),
              avatar: Icon(
                Icons.add_rounded,
                size: 17,
                color: colors.primary,
              ),
              label: Text(
                hasCustomCategory ? 'Đổi danh mục' : 'Khác',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed:
                  enabled ? () => _showCustomCategoryDialog(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class SpotQuickTagsSelector extends StatelessWidget {
  const SpotQuickTagsSelector({
    super.key,
    required this.category,
    required this.bestTimeTag,
    required this.difficultyTag,
    required this.priceTag,
    required this.enabled,
    required this.onBestTimeChanged,
    required this.onDifficultyChanged,
    required this.onPriceChanged,
  });

  final String category;
  final String bestTimeTag;
  final String difficultyTag;
  final String priceTag;
  final bool enabled;
  final ValueChanged<String> onBestTimeChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<String> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedTransports = SpotTagPresets.parseMultiTag(difficultyTag);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Tags thực chiến',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tùy chọn',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm lại để bỏ chọn hoặc bấm "+ Tự nhập" nếu muốn ghi chi tiết riêng.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _QuickTagGroup(
            icon: Icons.wb_sunny_outlined,
            label: SpotTagPresets.bestTimeLabelFor(category),
            options: SpotTagPresets.bestTimeOptionsFor(category),
            selectedValue: bestTimeTag,
            customHint: 'VD: 16h30–18h nắng đẹp, Thứ 7 mở cửa...',
            enabled: enabled,
            onChanged: onBestTimeChanged,
          ),
          const SizedBox(height: 16),
          _MultiSelectTransportGroup(
            label: SpotTagPresets.transportLabelFor(category),
            options: SpotTagPresets.transportOptionsFor(category),
            selectedValues: selectedTransports,
            enabled: enabled,
            onChanged: (updated) =>
                onDifficultyChanged(SpotTagPresets.joinMultiTag(updated)),
          ),
          const SizedBox(height: 16),
          _QuickTagGroup(
            icon: Icons.payments_outlined,
            label: SpotTagPresets.priceLabelFor(category),
            options: SpotTagPresets.priceOptionsFor(category),
            selectedValue: priceTag,
            customHint: 'VD: 35k/tô, Vé 40k/người, Gửi xe 5k...',
            enabled: enabled,
            onChanged: onPriceChanged,
          ),
        ],
      ),
    );
  }
}

class _MultiSelectTransportGroup extends StatelessWidget {
  const _MultiSelectTransportGroup({
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String> selectedValues;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  void _toggleOption(String option) {
    final next = List<String>.from(selectedValues);
    final index =
        next.indexWhere((item) => item.toLowerCase() == option.toLowerCase());
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.add(option);
    }
    onChanged(next);
  }

  Future<void> _openAddCustomDialog(BuildContext context) async {
    final result = await _showCustomTagDialog(
      context: context,
      title: 'Thêm phương tiện khác',
      initialValue: '',
      hintText: 'VD: Cáp treo, Xe điện, Tàu hỏa...',
      maxLength: 30,
    );
    if (result == null || result.trim().isEmpty) return;

    final added = SpotTagPresets.parseMultiTag(result);
    if (added.isEmpty) return;

    final next = List<String>.from(selectedValues);
    for (final item in added) {
      final exists = next.any((e) => e.toLowerCase() == item.toLowerCase());
      if (!exists) {
        next.add(item);
      }
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final optionSet = options.map((e) => e.toLowerCase()).toSet();
    final customValues = selectedValues
        .where((item) => !optionSet.contains(item.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.commute_outlined,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (selectedValues.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selectedValues.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              )
            else
              Text(
                '(Chọn nhiều)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (selectedValues.isNotEmpty && enabled) ...[
              const Spacer(),
              _DangerHighlightButton(
                label: 'Xóa hết',
                onTap: () => onChanged(const []),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                avatar: Icon(
                  transportIconFor(option),
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                label: Text(option),
                selected: selectedValues
                    .any((e) => e.toLowerCase() == option.toLowerCase()),
                onSelected: enabled ? (_) => _toggleOption(option) : null,
              ),
            for (final custom in customValues)
              InputChip(
                avatar: Icon(
                  transportIconFor(custom),
                  size: 16,
                  color: colors.onSecondaryContainer,
                ),
                label: Text(custom),
                selected: true,
                deleteIconColor: colors.error,
                onDeleted: enabled ? () => _toggleOption(custom) : null,
              ),
            ActionChip(
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.45),
              side: BorderSide(
                color: colors.primary.withValues(alpha: 0.45),
              ),
              avatar: Icon(
                Icons.add_rounded,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                'Tự nhập',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: enabled ? () => _openAddCustomDialog(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTagGroup extends StatelessWidget {
  const _QuickTagGroup({
    required this.icon,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.customHint,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<String> options;
  final String selectedValue;
  final String customHint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  Future<void> _openCustomDialog(BuildContext context) async {
    final isCustom =
        selectedValue.isNotEmpty && !options.contains(selectedValue);
    final result = await _showCustomTagDialog(
      context: context,
      title: label,
      initialValue: isCustom ? selectedValue : '',
      hintText: customHint,
      maxLength: 36,
    );
    if (result != null && result.isNotEmpty) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasCustomValue =
        selectedValue.isNotEmpty && !options.contains(selectedValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selectedValue.isNotEmpty && enabled) ...[
              const SizedBox(width: 8),
              _DangerHighlightButton(
                label: 'Bỏ chọn',
                onTap: () => onChanged(''),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: selectedValue == option,
                onSelected: enabled
                    ? (selected) => onChanged(selected ? option : '')
                    : null,
              ),
            if (hasCustomValue)
              InputChip(
                label: Text(selectedValue),
                selected: true,
                deleteIconColor: colors.error,
                onPressed: enabled ? () => _openCustomDialog(context) : null,
                onDeleted: enabled ? () => onChanged('') : null,
              ),
            ActionChip(
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.45),
              side: BorderSide(
                color: colors.primary.withValues(alpha: 0.45),
              ),
              avatar: Icon(
                Icons.add_rounded,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                'Tự nhập',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: enabled ? () => _openCustomDialog(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}

Future<String?> _showCustomTagDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String hintText,
  required int maxLength,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            Navigator.of(dialogContext).pop(trimmed);
          }
        },
        decoration: InputDecoration(
          hintText: hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () {
            final trimmed = controller.text.trim();
            Navigator.of(dialogContext).pop(trimmed.isEmpty ? null : trimmed);
          },
          child: const Text(
            'Áp dụng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}