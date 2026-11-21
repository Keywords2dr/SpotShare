import 'package:flutter/material.dart';

import '../../data/explore_feed_repository.dart';

class ExploreFilterSelection {
  const ExploreFilterSelection({
    this.category = ExploreFeedFilterPresets.allCategory,
    this.price,
    this.bestTime,
  });

  final String category;
  final String? price;
  final String? bestTime;
}

class ExploreFilterSheet extends StatefulWidget {
  const ExploreFilterSheet({
    super.key,
    this.initialCategory = ExploreFeedFilterPresets.allCategory,
    this.initialPrice,
    this.initialBestTime,
    this.onApply,
  });

  final String initialCategory;
  final String? initialPrice;
  final String? initialBestTime;
  final ValueChanged<ExploreFilterSelection>? onApply;

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  late String _selectedCategory;
  String? _selectedPrice;
  String? _selectedBestTime;

  bool get _hasAnyFilter =>
      _selectedCategory != ExploreFeedFilterPresets.allCategory ||
      _selectedPrice != null ||
      _selectedBestTime != null;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory.trim().isEmpty
        ? ExploreFeedFilterPresets.allCategory
        : widget.initialCategory.trim();
    _selectedPrice = widget.initialPrice;
    _selectedBestTime = widget.initialBestTime;
  }

  void _reset() {
    setState(() {
      _selectedCategory = ExploreFeedFilterPresets.allCategory;
      _selectedPrice = null;
      _selectedBestTime = null;
    });
  }

  void _apply() {
    final selection = ExploreFilterSelection(
      category: _selectedCategory,
      price: _selectedPrice,
      bestTime: _selectedBestTime,
    );
    if (widget.onApply != null) {
      widget.onApply!(selection);
    } else {
      Navigator.of(context).pop(selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bộ lọc địa điểm',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('explore_filter_reset_button'),
                    onPressed: _hasAnyFilter ? _reset : null,
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Danh mục',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ExploreFeedFilterPresets.categories)
                    ChoiceChip(
                      key: Key('explore_filter_category_$category'),
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected
                              ? category
                              : ExploreFeedFilterPresets.allCategory;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Khoảng giá tham khảo',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final price in ExploreFeedFilterPresets.priceRanges)
                    ChoiceChip(
                      key: Key('explore_filter_price_$price'),
                      label: Text(price),
                      selected: _selectedPrice == price,
                      onSelected: (selected) {
                        setState(() {
                          _selectedPrice = selected ? price : null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Khung giờ đẹp nhất',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in ExploreFeedFilterPresets.bestTimes)
                    ChoiceChip(
                      key: Key('explore_filter_time_$time'),
                      label: Text(time),
                      selected: _selectedBestTime == time,
                      onSelected: (selected) {
                        setState(() {
                          _selectedBestTime = selected ? time : null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('explore_filter_apply_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _apply,
                child: const Text(
                  'Áp dụng bộ lọc',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}