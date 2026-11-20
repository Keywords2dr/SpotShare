import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/place_search_service.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../domain/spot_model.dart';
import '../spot_providers.dart';

class EditSpotScreen extends ConsumerStatefulWidget {
  const EditSpotScreen({
    super.key,
    required this.spotId,
    this.initialSpot,
  });

  final String spotId;
  final SpotModel? initialSpot;

  @override
  ConsumerState<EditSpotScreen> createState() => _EditSpotScreenState();
}

class _EditSpotScreenState extends ConsumerState<EditSpotScreen> {
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
  final List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];

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

  bool _isInitialized = false;
  bool _isSaving = false;
  String _statusMessage = '';
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSpot != null) {
      _populateFromSpot(widget.initialSpot!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _placeSearchController.dispose();
    super.dispose();
  }

  void _populateFromSpot(SpotModel spot) {
    if (_isInitialized) return;
    _isInitialized = true;
    _titleController.text = spot.title;
    _descriptionController.text = spot.description;
    _placeSearchController.text = spot.addressText;
    _selectedAddress = spot.addressText;
    _selectedLat = spot.latitude;
    _selectedLng = spot.longitude;
    _existingImageUrls
      ..clear()
      ..addAll(spot.imageUrls);

    if (_categories.contains(spot.category)) {
      _selectedCategory = spot.category;
    }
    if (_bestTimeOptions.contains(spot.bestTimeTag)) {
      _selectedBestTime = spot.bestTimeTag;
    }
    if (_difficultyOptions.contains(spot.difficultyTag)) {
      _selectedDifficulty = spot.difficultyTag;
    }
    if (_priceOptions.contains(spot.priceTag)) {
      _selectedPrice = spot.priceTag;
    }
  }

  int get _totalImagesCount => _existingImageUrls.length + _newImages.length;

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
    final remaining = 6 - _totalImagesCount;
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
          if (_totalImagesCount < 6) {
            _newImages.add(file);
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

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập lại.')),
      );
      return;
    }

    if (_totalImagesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài đăng cần có ít nhất 1 ảnh.')),
      );
      return;
    }

    if (_selectedLat == null ||
        _selectedLng == null ||
        _selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tìm và chọn địa chỉ từ danh sách gợi ý.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
      _statusMessage = _newImages.isNotEmpty
          ? 'Đang tải ảnh mới lên Cloudinary...'
          : 'Đang lưu thay đổi lên Firestore...';
    });

    try {
      final finalImageUrls = List<String>.from(_existingImageUrls);

      if (_newImages.isNotEmpty) {
        final uploadedUrls =
            await ref.read(cloudinaryServiceProvider).uploadImages(
          _newImages,
          onFileProgress: (index, total, progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = ((index + progress) / total).clamp(0.0, 1.0);
              _statusMessage =
                  'Đang tải ảnh mới ${index + 1}/$total (${(progress * 100).round()}%)...';
            });
          },
        );
        finalImageUrls.addAll(uploadedUrls);
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
          _statusMessage = 'Đang cập nhật bài viết...';
        });
      }

      await ref.read(spotRepositoryProvider).updateSpot(
            spotId: widget.spotId,
            currentUserId: authUser.uid,
            title: _titleController.text,
            description: _descriptionController.text,
            category: _selectedCategory,
            imageUrls: finalImageUrls,
            latitude: _selectedLat!,
            longitude: _selectedLng!,
            addressText: _selectedAddress,
            bestTimeTag: _selectedBestTime,
            difficultyTag: _selectedDifficulty,
            priceTag: _selectedPrice,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật bài đăng!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
    final spotAsync = ref.watch(spotDetailProvider(widget.spotId));
    final spot = spotAsync.value ?? widget.initialSpot;

    if (!_isInitialized && spot != null) {
      _populateFromSpot(spot);
    }

    if (spotAsync.isLoading && spot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chỉnh sửa bài đăng')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (spot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chỉnh sửa bài đăng')),
        body: const Center(
          child: Text('Không tìm thấy bài đăng cần chỉnh sửa.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final totalItems = _totalImagesCount + (_totalImagesCount < 6 ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa bài đăng'),
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
                  'Hình ảnh ($_totalImagesCount/6)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Thêm ảnh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: totalItems,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index < _existingImageUrls.length) {
                    final thumbUrl = CloudinaryUrlHelper.feedThumbnail(
                      _existingImageUrls[index],
                    );
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: thumbUrl,
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              width: 108,
                              height: 108,
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, _, _) => Container(
                              width: 108,
                              height: 108,
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        if (!_isSaving)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removeExistingImage(index),
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
                  }

                  final newIndex = index - _existingImageUrls.length;
                  if (newIndex < _newImages.length) {
                    final file = _newImages[newIndex];
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
                        if (!_isSaving)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removeNewImage(newIndex),
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
                  }

                  return InkWell(
                    onTap: _isSaving ? null : _pickImages,
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
                },
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusMessage.isNotEmpty
                            ? _statusMessage
                            : 'Đang lưu...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _newImages.isNotEmpty ? _uploadProgress : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _placeSearchController,
              enabled: !_isSaving,
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
                            onPressed: _isSaving ? null : _clearSelectedPlace,
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
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên địa điểm *',
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
              onSelected: _isSaving
                  ? (_) {}
                  : (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              enabled: !_isSaving,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mô tả trải nghiệm thực tế *',
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
              onSelected: _isSaving
                  ? (_) {}
                  : (value) => setState(() => _selectedBestTime = value),
            ),
            const SizedBox(height: 16),
            _buildChoiceSection(
              label: 'Quick Tag — Đường đi',
              options: _difficultyOptions,
              selectedValue: _selectedDifficulty,
              onSelected: _isSaving
                  ? (_) {}
                  : (value) => setState(() => _selectedDifficulty = value),
            ),
            const SizedBox(height: 16),
            _buildChoiceSection(
              label: 'Quick Tag — Khoảng giá tham khảo',
              options: _priceOptions,
              selectedValue: _selectedPrice,
              onSelected: _isSaving
                  ? (_) {}
                  : (value) => setState(() => _selectedPrice = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}