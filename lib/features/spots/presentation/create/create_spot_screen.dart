import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/place_search_service.dart';
import '../../../../core/services/service_providers.dart';
import 'create_spot_controller.dart';

class CreateSpotScreen extends ConsumerStatefulWidget {
  const CreateSpotScreen({super.key});

  @override
  ConsumerState<CreateSpotScreen> createState() => _CreateSpotScreenState();
}

class _CreateSpotScreenState extends ConsumerState<CreateSpotScreen> {
  static const List<String> _categories = [
    'Bãi biển',
    'Cảnh đẹp / Check-in',
    'Món ăn ngon',
    'Quán cà phê view đẹp',
  ];

  static const List<String> _bestTimeOptions = [
    'Sáng sớm (5h–8h)',
    'Chiều hoàng hôn (16h–18h)',
    'Buổi tối / Đêm',
    'Cả ngày',
  ];

  static const List<String> _difficultyOptions = [
    'Dễ đi / Ô tô tới nơi',
    'Xe máy / Đường đèo nhẹ',
    'Đi bộ / Trekking ngắn',
  ];

  static const List<String> _priceOptions = [
    'Miễn phí',
    '< 50k',
    '50k – 150k',
    '> 150k',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeSearchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearchingPlace = false;
  String? _placeError;

  String _selectedAddress = '';
  double? _selectedLat;
  double? _selectedLng;

  String _selectedCategory = _categories.first;
  String _selectedBestTime = _bestTimeOptions.first;
  String _selectedDifficulty = _difficultyOptions.first;
  String _selectedPrice = _priceOptions[2];

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _placeSearchController.dispose();
    super.dispose();
  }

  void _onPlaceQueryChanged(String query) {
    _debounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = [];
        _placeError = null;
        _isSearchingPlace = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchPlaces(trimmed);
    });
  }

  Future<void> _searchPlaces(String query) async {
    final searchService = ref.read(placeSearchServiceProvider);

    setState(() {
      _isSearchingPlace = true;
      _placeError = null;
    });

    try {
      final results = await searchService.search(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearchingPlace = false;
        if (results.isEmpty) {
          _placeError =
              'Không tìm thấy địa chỉ phù hợp. Thử nhập thêm tên tỉnh/thành phố.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isSearchingPlace = false;
        _placeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _selectedAddress = suggestion.fullText;
      _selectedLat = suggestion.latitude;
      _selectedLng = suggestion.longitude;
      _placeSearchController.text = suggestion.fullText;
      if (_titleController.text.trim().isEmpty &&
          suggestion.mainText.isNotEmpty) {
        _titleController.text = suggestion.mainText;
      }
      _suggestions = [];
      _placeError = null;
    });
  }

  void _clearSelectedPlace() {
    setState(() {
      _placeSearchController.clear();
      _selectedAddress = '';
      _selectedLat = null;
      _selectedLng = null;
      _suggestions = [];
      _placeError = null;
    });
  }

  Future<void> _pickImages() async {
    final remaining = 6 - _selectedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đạt giới hạn tối đa 6 ảnh.')),
      );
      return;
    }

    try {
      final files = await _picker.pickMultiImage(limit: remaining);
      if (!mounted || files.isEmpty) return;

      setState(() {
        for (final file in files) {
          if (_selectedImages.length < 6) {
            _selectedImages.add(file);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở thư viện ảnh: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 ảnh địa điểm.')),
      );
      return;
    }

    if (_selectedLat == null ||
        _selectedLng == null ||
        _selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng tìm và chọn địa chỉ từ danh sách gợi ý.',
          ),
        ),
      );
      return;
    }

    final ok = await ref.read(createSpotControllerProvider.notifier).publishSpot(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          pickedImages: List<XFile>.from(_selectedImages),
          latitude: _selectedLat!,
          longitude: _selectedLng!,
          addressText: _selectedAddress,
          bestTimeTag: _selectedBestTime,
          difficultyTag: _selectedDifficulty,
          priceTag: _selectedPrice,
        );

    if (!mounted) return;

    if (ok) {
      _titleController.clear();
      _descriptionController.clear();
      _clearSelectedPlace();
      setState(() {
        _selectedImages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng địa điểm thành công!')),
      );
      context.go('/explore');
    }
  }

  Widget _buildChoiceSection({
    required String label,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selectedValue;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CreateSpotUploadState>>(
      createSpotControllerProvider,
      (_, next) {
        if (next.hasError && mounted) {
          final message = next.error.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
    );

    final asyncState = ref.watch(createSpotControllerProvider);
    final uploadState = asyncState.value ?? const CreateSpotUploadState();
    final isBusy = asyncState.isLoading || uploadState.isSubmitting;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng địa điểm'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hình ảnh (${_selectedImages.length}/6)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: isBusy ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Chọn ảnh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length +
                    (_selectedImages.length < 6 ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return InkWell(
                      onTap: isBusy ? null : _pickImages,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 108,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          color: theme.colorScheme.surfaceContainerLow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thêm ảnh',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final file = _selectedImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          file.path,
                          width: 108,
                          height: 108,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 108,
                            height: 108,
                            color: theme.colorScheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              file.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                      if (!isBusy)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (isBusy) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uploadState.statusMessage.isNotEmpty
                            ? uploadState.statusMessage
                            : 'Đang xử lý...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: uploadState.totalCount > 0
                            ? uploadState.overallProgress
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _placeSearchController,
              enabled: !isBusy,
              onChanged: _onPlaceQueryChanged,
              decoration: InputDecoration(
                labelText: 'Tìm địa chỉ (OpenStreetMap) *',
                hintText: 'VD: Eo Gió Quy Nhơn, Hồ Xuân Hương Đà Lạt...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearchingPlace
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_placeSearchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: isBusy ? null : _clearSelectedPlace,
                            icon: const Icon(Icons.clear),
                          )
                        : null),
              ),
            ),
            if (_placeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _placeError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        item.mainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.secondaryText.isNotEmpty
                          ? Text(
                              item.secondaryText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _selectSuggestion(item),
                    );
                  },
                ),
              ),
            ],
            if (_selectedLat != null && _selectedLng != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GPS: ${_selectedLat!.toStringAsFixed(5)}, ${_selectedLng!.toStringAsFixed(5)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên địa điểm *',
                hintText: 'VD: Eo Gió, Quán bánh xèo tôm nhảy...',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Vui lòng nhập tên địa điểm';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildChoiceSection(
              label: 'Danh mục chính *',
              options: _categories,
              selectedValue: _selectedCategory,
              onSelected: isBusy
                  ? (_) {}
                  : (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              enabled: !isBusy,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mô tả trải nghiệm thực tế *',
                hintText: 'Chia sẻ khung cảnh, món ăn, lưu ý đường đi...',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Vui lòng nhập mô tả địa điểm';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildChoiceSection(
              label: 'Quick Tag — Giờ đẹp nhất',
              options: _bestTimeOptions,
              selectedValue: _selectedBestTime,
              onSelected: isBusy
                  ? (_) {}
                  : (value) => setState(() => _selectedBestTime = value),
            ),
            const SizedBox(height: 16),
            _buildChoiceSection(
              label: 'Quick Tag — Đường đi',
              options: _difficultyOptions,
              selectedValue: _selectedDifficulty,
              onSelected: isBusy
                  ? (_) {}
                  : (value) => setState(() => _selectedDifficulty = value),
            ),
            const SizedBox(height: 16),
            _buildChoiceSection(
              label: 'Quick Tag — Khoảng giá tham khảo',
              options: _priceOptions,
              selectedValue: _selectedPrice,
              onSelected: isBusy
                  ? (_) {}
                  : (value) => setState(() => _selectedPrice = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isBusy ? null : _submit,
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(isBusy ? 'Đang đăng địa điểm...' : 'Đăng địa điểm'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}