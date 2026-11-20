import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'spot_providers.dart';

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
  final _addressController = TextEditingController();
  final _latController = TextEditingController(text: '13.7820');
  final _lngController = TextEditingController(text: '109.2197');

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  String _selectedCategory = _categories.first;
  String _selectedBestTime = _bestTimeOptions.first;
  String _selectedDifficulty = _difficultyOptions.first;
  String _selectedPrice = _priceOptions[2];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tọa độ GPS (Vĩ độ / Kinh độ) không hợp lệ.')),
      );
      return;
    }

    final ok = await ref.read(createSpotControllerProvider.notifier).publishSpot(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          pickedImages: List<XFile>.from(_selectedImages),
          latitude: lat,
          longitude: lng,
          addressText: _addressController.text,
          bestTimeTag: _selectedBestTime,
          difficultyTag: _selectedDifficulty,
          priceTag: _selectedPrice,
        );

    if (!mounted) return;

    if (ok) {
      _titleController.clear();
      _descriptionController.clear();
      _addressController.clear();
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
    ref.listen<AsyncValue<CreateSpotUploadState>>(createSpotControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final message = next.error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

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
                itemCount: _selectedImages.length + (_selectedImages.length < 6 ? 1 : 0),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ / Khu vực *',
                hintText: 'VD: Nhơn Lý, Quy Nhơn, Gia Lai',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Vui lòng nhập địa chỉ hoặc khu vực';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    enabled: !isBusy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Vĩ độ (Lat)',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    enabled: !isBusy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Kinh độ (Lng)',
                      prefixIcon: Icon(Icons.explore_outlined),
                    ),
                  ),
                ),
              ],
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