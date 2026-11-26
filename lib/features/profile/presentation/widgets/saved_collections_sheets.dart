import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/cloudinary_url_helper.dart';
import '../../data/saved_collections_repository.dart';
import '../saved_collections_controller.dart';

IconData collectionIconFor(String iconKey) {
  switch (iconKey) {
    case 'beach':
      return Icons.beach_access_rounded;
    case 'food':
      return Icons.restaurant_rounded;
    case 'coffee':
      return Icons.local_cafe_rounded;
    case 'view':
      return Icons.landscape_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'trip':
    default:
      return Icons.luggage_rounded;
  }
}

class CollectionEditorSheet extends ConsumerStatefulWidget {
  const CollectionEditorSheet({
    super.key,
    required this.userId,
    this.existingCollection,
    this.initialSpotIds = const [],
    this.seedSpot,
    this.onSaved,
  });

  final String userId;
  final SpotCollectionModel? existingCollection;
  final List<String> initialSpotIds;
  final SavedSpotItem? seedSpot;
  final ValueChanged<SpotCollectionModel?>? onSaved;

  @override
  ConsumerState<CollectionEditorSheet> createState() =>
      _CollectionEditorSheetState();
}

class _CollectionEditorSheetState extends ConsumerState<CollectionEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _iconKey;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingCollection != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingCollection?.name ?? '');
    _descController = TextEditingController(
      text: widget.existingCollection?.description ?? '',
    );
    _iconKey = widget.existingCollection?.iconKey ?? 'trip';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final notifier = ref.read(savedCollectionsControllerProvider.notifier);
    final SavedCollectionActionResult result;

    if (_isEditing) {
      result = await notifier.updateCollection(
        userId: widget.userId,
        collectionId: widget.existingCollection!.id,
        name: _nameController.text,
        description: _descController.text,
        iconKey: _iconKey,
      );
    } else {
      result = await notifier.createCollection(
        userId: widget.userId,
        name: _nameController.text,
        description: _descController.text,
        iconKey: _iconKey,
        initialSpotIds: widget.initialSpotIds,
        seedSpot: widget.seedSpot,
      );
    }

    if (!mounted) return;
    if (result.success) {
      setState(() => _isSaving = false);
      if (widget.onSaved != null) {
        widget.onSaved!(result.createdCollection);
      } else {
        Navigator.of(context).pop(result.createdCollection ?? true);
      }
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = result.errorMessage ?? 'Không thể lưu bộ sưu tập.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomInset),
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
              Text(
                _isEditing ? 'Chỉnh sửa bộ sưu tập' : 'Tạo bộ sưu tập mới',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('collection_name_field'),
                controller: _nameController,
                enabled: !_isSaving,
                maxLength: SavedCollectionsLogic.maxCollectionNameLength,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Tên bộ sưu tập',
                  hintText: 'VD: Du lịch cuối tuần, Quán ngon Quy Nhơn...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final suggestion
                        in SavedCollectionsLogic.quickNameSuggestions)
                      ActionChip(
                        key: Key('collection_suggestion_$suggestion'),
                        label: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: _isSaving
                            ? null
                            : () {
                                _nameController.text = suggestion;
                                setState(() => _errorMessage = null);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 6),
              TextField(
                key: const Key('collection_desc_field'),
                controller: _descController,
                enabled: !_isSaving,
                maxLines: 2,
                maxLength: SavedCollectionsLogic.maxDescriptionLength,
                decoration: InputDecoration(
                  labelText: 'Ghi chú chuyến đi (không bắt buộc)',
                  hintText: 'Lịch trình dự kiến, ngân sách hoặc lưu ý...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Biểu tượng chủ đề',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in SavedCollectionsLogic.iconOptions)
                    ChoiceChip(
                      key: Key('collection_icon_${option.key}'),
                      avatar: Icon(
                        collectionIconFor(option.key),
                        size: 16,
                      ),
                      label: Text(option.label),
                      selected: _iconKey == option.key,
                      onSelected: _isSaving
                          ? null
                          : (_) => setState(() => _iconKey = option.key),
                    ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('collection_editor_error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('collection_save_button'),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Lưu thay đổi' : 'Tạo bộ sưu tập',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignSpotToCollectionsSheet extends ConsumerStatefulWidget {
  const AssignSpotToCollectionsSheet({
    super.key,
    required this.userId,
    required this.spotId,
    required this.spotTitle,
    this.spotFallback,
    this.onDone,
  });

  final String userId;
  final String spotId;
  final String spotTitle;
  final SavedSpotItem? spotFallback;
  final ValueChanged<int>? onDone;

  @override
  ConsumerState<AssignSpotToCollectionsSheet> createState() =>
      _AssignSpotToCollectionsSheetState();
}

class _AssignSpotToCollectionsSheetState
    extends ConsumerState<AssignSpotToCollectionsSheet> {
  final Set<String> _selectedIds = <String>{};
  bool _initialized = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(savedCollectionsControllerProvider.notifier);
      final current = notifier.stateFor(widget.userId);
      if (!current.hasLoaded) {
        await notifier.load(userId: widget.userId);
      }
      if (!mounted) return;
      _syncInitialSelection();
    });
  }

  void _syncInitialSelection() {
    if (_initialized) return;
    final view = ref
        .read(savedCollectionsControllerProvider.notifier)
        .stateFor(widget.userId);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          view.collections
              .where((col) => col.spotIds.contains(widget.spotId))
              .map((col) => col.id),
        );
      _initialized = true;
    });
  }

  Future<void> _createAndSelectCollection() async {
    final created = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionEditorSheet(
        userId: widget.userId,
      ),
    );
    if (!mounted) return;
    if (created is SpotCollectionModel) {
      setState(() {
        _selectedIds.add(created.id);
        _initialized = true;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .setSpotCollections(
          userId: widget.userId,
          spotId: widget.spotId,
          targetCollectionIds: _selectedIds,
          spotFallback: widget.spotFallback,
        );

    if (!mounted) return;
    if (result.success) {
      setState(() => _isSaving = false);
      if (widget.onDone != null) {
        widget.onDone!(_selectedIds.length);
      } else {
        Navigator.of(context).pop(_selectedIds.length);
      }
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = result.errorMessage ?? 'Không thể cập nhật phân loại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(
      savedCollectionsControllerProvider.select(
        (map) => map[widget.userId] ?? const SavedCollectionsViewState(),
      ),
    );
    if (!_initialized && viewState.hasLoaded) {
      _selectedIds
        ..clear()
        ..addAll(
          viewState.collections
              .where((col) => col.spotIds.contains(widget.spotId))
              .map((col) => col.id),
        );
      _initialized = true;
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn bộ sưu tập',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.spotTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('assign_create_collection_button'),
                  onPressed: _isSaving ? null : _createAndSelectCollection,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tạo mới'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _selectedIds.isEmpty
                  ? 'Bài viết sẽ vẫn nằm trong mục Đã lưu (chưa thuộc bộ sưu tập nào).'
                  : 'Bài viết luôn có ở mục Đã lưu và đồng thời thêm vào ${_selectedIds.length} bộ sưu tập đã chọn.',
              key: const Key('assign_mode_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (viewState.isInitialLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (viewState.collections.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 28,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bạn chưa tạo bộ sưu tập nào',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bấm Tạo mới để gom địa điểm theo chuyến đi hoặc chủ đề riêng.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: viewState.collections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final col = viewState.collections[index];
                    final selected = _selectedIds.contains(col.id);
                    return Material(
                      color: selected
                          ? colors.primaryContainer.withValues(alpha: 0.48)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: CheckboxListTile(
                        key: Key('assign_collection_tile_${col.id}'),
                        value: selected,
                        dense: true,
                        onChanged: _isSaving
                            ? null
                            : (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIds.add(col.id);
                                  } else {
                                    _selectedIds.remove(col.id);
                                  }
                                });
                              },
                        secondary: CircleAvatar(
                          radius: 17,
                          backgroundColor: colors.surfaceContainerHighest,
                          child: Icon(
                            collectionIconFor(col.iconKey),
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                        title: Text(
                          col.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${col.spotIds.length} địa điểm'),
                      ),
                    );
                  },
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('assign_save_button'),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _selectedIds.isEmpty
                          ? 'Xong'
                          : 'Lưu vào ${_selectedIds.length} bộ sưu tập',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class RemoveSpotFromCollectionsSheet extends ConsumerStatefulWidget {
  const RemoveSpotFromCollectionsSheet({
    super.key,
    required this.userId,
    required this.spotId,
    required this.spotTitle,
  });

  final String userId;
  final String spotId;
  final String spotTitle;

  @override
  ConsumerState<RemoveSpotFromCollectionsSheet> createState() =>
      _RemoveSpotFromCollectionsSheetState();
}

class _RemoveSpotFromCollectionsSheetState
    extends ConsumerState<RemoveSpotFromCollectionsSheet> {
  String? _removingCollectionId;
  String? _errorMessage;

  Future<void> _removeFrom(SpotCollectionModel col) async {
    if (_removingCollectionId != null) return;
    setState(() {
      _removingCollectionId = col.id;
      _errorMessage = null;
    });

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .removeSpotFromCollection(
          userId: widget.userId,
          collectionId: col.id,
          spotId: widget.spotId,
        );

    if (!mounted) return;
    setState(() => _removingCollectionId = null);

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Không thể xóa địa điểm.';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(
      savedCollectionsControllerProvider.select(
        (map) => map[widget.userId] ?? const SavedCollectionsViewState(),
      ),
    );
    final containing = viewState.collectionsContainingSpot(widget.spotId);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            Text(
              'Xóa khỏi bộ sưu tập & Đã lưu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${widget.spotTitle}" đang thuộc ${containing.length} bộ sưu tập. Bấm Xóa sẽ xóa địa điểm này khỏi mục Đã lưu và tất cả bộ sưu tập:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (containing.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Đã xóa hoàn toàn khỏi mục Đã lưu và tất cả bộ sưu tập.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: containing.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final col = containing[index];
                    final isRemoving = _removingCollectionId == col.id;
                    return Material(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: colors.surfaceContainerHighest,
                          child: Icon(
                            collectionIconFor(col.iconKey),
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                        title: Text(
                          col.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${col.spotIds.length} địa điểm'),
                        trailing: TextButton(
                          key: Key('remove_from_collection_btn_${col.id}'),
                          onPressed: _removingCollectionId != null
                              ? null
                              : () => _removeFrom(col),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          child: isRemoving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Xóa',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageCollectionSpotsSheet extends ConsumerStatefulWidget {
  const ManageCollectionSpotsSheet({
    super.key,
    required this.userId,
    required this.collection,
    this.onDone,
  });

  final String userId;
  final SpotCollectionModel collection;
  final VoidCallback? onDone;

  @override
  ConsumerState<ManageCollectionSpotsSheet> createState() =>
      _ManageCollectionSpotsSheetState();
}

class _ManageCollectionSpotsSheetState
    extends ConsumerState<ManageCollectionSpotsSheet> {
  late final Set<String> _selectedSpotIds;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSpotIds = Set<String>.from(widget.collection.spotIds);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .setCollectionSpots(
          userId: widget.userId,
          collectionId: widget.collection.id,
          spotIds: _selectedSpotIds.toList(),
        );

    if (!mounted) return;
    if (result.success) {
      setState(() => _isSaving = false);
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = result.errorMessage ?? 'Không thể cập nhật địa điểm.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(
      savedCollectionsControllerProvider.select(
        (map) => map[widget.userId] ?? const SavedCollectionsViewState(),
      ),
    );
    final selectableSpots = viewState.allSelectableSpots;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            Text(
              'Chọn địa điểm cho "${widget.collection.name}"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đã chọn ${_selectedSpotIds.length} địa điểm.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (selectableSpots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có địa điểm nào để thêm. Hãy bấm Lưu trên các bài viết bạn yêu thích trước nhé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: selectableSpots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final spot = selectableSpots[index];
                    final selected = _selectedSpotIds.contains(spot.id);
                    return Material(
                      color: selected
                          ? colors.primaryContainer.withValues(alpha: 0.45)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: CheckboxListTile(
                        key: Key('manage_spot_checkbox_${spot.id}'),
                        value: selected,
                        dense: true,
                        onChanged: _isSaving
                            ? null
                            : (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedSpotIds.add(spot.id);
                                  } else {
                                    _selectedSpotIds.remove(spot.id);
                                  }
                                });
                              },
                        title: Text(
                          spot.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          spot.category.isNotEmpty
                              ? spot.category
                              : 'Địa điểm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('manage_spots_save_button'),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Lưu thay đổi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeleteCollectionDialog extends StatelessWidget {
  const DeleteCollectionDialog({
    super.key,
    required this.collectionName,
  });

  final String collectionName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Xóa bộ sưu tập'),
      content: Text(
        'Bạn có chắc muốn xóa bộ sưu tập "$collectionName" không? Toàn bộ địa điểm bên trong cũng sẽ bị xóa khỏi mục Đã lưu và tất cả bộ sưu tập khác.',
      ),
      actions: [
        TextButton(
          key: const Key('delete_collection_cancel_button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('delete_collection_confirm_button'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Xóa hết',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({
    super.key,
    required this.userId,
    required this.collectionId,
    this.onSpotTap,
    this.onPlanTripTap,
  });

  final String userId;
  final String collectionId;
  final void Function(SavedSpotItem spot)? onSpotTap;
  final void Function(SpotCollectionModel collection, SavedSpotList spots)?
      onPlanTripTap;

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editCollection(
    BuildContext context,
    SpotCollectionModel collection,
  ) async {
    final updated = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionEditorSheet(
        userId: userId,
        existingCollection: collection,
      ),
    );
    if (updated != null && context.mounted) {
      _showSnackBar(context, 'Đã cập nhật bộ sưu tập.');
    }
  }

  Future<void> _manageSpots(
    BuildContext context,
    SpotCollectionModel collection,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManageCollectionSpotsSheet(
        userId: userId,
        collection: collection,
      ),
    );
    if (updated == true && context.mounted) {
      _showSnackBar(context, 'Đã cập nhật địa điểm trong bộ sưu tập.');
    }
  }

  Future<void> _deleteCollection(
    BuildContext context,
    WidgetRef ref,
    SpotCollectionModel collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteCollectionDialog(collectionName: collection.name),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .deleteCollection(
          userId: userId,
          collectionId: collection.id,
        );
    if (!context.mounted) return;
    if (result.success) {
      Navigator.of(context).pop();
    } else if (result.errorMessage != null) {
      _showSnackBar(context, result.errorMessage!);
    }
  }

  Future<void> _removeSingleSpot(
    BuildContext context,
    WidgetRef ref,
    SpotCollectionModel collection,
    SavedSpotItem spot,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa địa điểm'),
        content: Text(
          'Xóa "${spot.title}" sẽ bỏ lưu hoàn toàn khỏi mục Đã lưu và tất cả bộ sưu tập. Bạn có chắc muốn xóa không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Xóa hết',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(savedCollectionsControllerProvider.notifier)
        .removeSpotFromCollection(
          userId: userId,
          collectionId: collection.id,
          spotId: spot.id,
        );
    if (!context.mounted) return;
    if (result.success) {
      _showSnackBar(
        context,
        'Đã xóa "${spot.title}" khỏi mục Đã lưu và tất cả bộ sưu tập.',
      );
    } else if (result.errorMessage != null) {
      _showSnackBar(context, result.errorMessage!);
    }
  }

  void _openSpot(BuildContext context, SavedSpotItem spot) {
    if (onSpotTap != null) {
      onSpotTap!(spot);
      return;
    }
    GoRouter.maybeOf(context)?.push('/spots/${spot.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(
      savedCollectionsControllerProvider.select(
        (map) => map[userId] ?? const SavedCollectionsViewState(),
      ),
    );
    SpotCollectionModel? collection;
    for (final col in viewState.collections) {
      if (col.id == collectionId) {
        collection = col;
        break;
      }
    }

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bộ sưu tập')),
        body: const Center(
          child: Text('Bộ sưu tập này không còn tồn tại.'),
        ),
      );
    }

    final activeCollection = collection;
    final spots = viewState.spotsInCollection(collectionId);
    final aiReadiness = SavedCollectionsLogic.evaluateAiReadiness(spots.length);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardExtent = SavedCollectionsLogic.resolveSavedCardExtent(textScale);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          activeCollection.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('collection_detail_add_spots_button'),
            tooltip: 'Thêm hoặc bớt địa điểm',
            onPressed: () => _manageSpots(context, activeCollection),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          PopupMenuButton<String>(
            key: const Key('collection_detail_menu_button'),
            tooltip: 'Tùy chọn bộ sưu tập',
            onSelected: (value) {
              if (value == 'edit') {
                _editCollection(context, activeCollection);
              } else if (value == 'delete') {
                _deleteCollection(context, ref, activeCollection);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Sửa tên & ghi chú',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: colors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Xóa bộ sưu tập',
                      style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          collectionIconFor(activeCollection.iconKey),
                          size: 20,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${spots.length} địa điểm đã chọn',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (activeCollection.description.isNotEmpty)
                              Text(
                                activeCollection.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('collection_ai_readiness_banner'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: aiReadiness.isReady
                          ? colors.primaryContainer.withValues(alpha: 0.45)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: aiReadiness.isReady
                            ? colors.primary.withValues(alpha: 0.35)
                            : colors.outlineVariant.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: aiReadiness.isReady
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aiReadiness.statusMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (aiReadiness.isReady) ...[
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            key: const Key('collection_ai_plan_button'),
                            onPressed: () {
                              if (onPlanTripTap != null) {
                                onPlanTripTap!(activeCollection, spots);
                              } else {
                                _showSnackBar(
                                  context,
                                  'Tính năng AI Xếp lịch trình (FR-22) sẵn sàng kết nối Gemini API.',
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            child: const Text(
                              'Lập lịch',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (spots.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_location_alt_outlined,
                        size: 36,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bộ sưu tập chưa có địa điểm nào',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bấm Lưu trên bài viết và chọn bộ sưu tập này, hoặc thêm địa điểm ngay tại đây.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        key: const Key('collection_empty_add_button'),
                        onPressed: () =>
                            _manageSpots(context, activeCollection),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Thêm địa điểm'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final spot = spots[index];
                    final thumbUrl = spot.thumbnailUrl.isNotEmpty
                        ? CloudinaryUrlHelper.feedThumbnail(spot.thumbnailUrl)
                        : '';
                    return Material(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('collection_detail_spot_${spot.id}'),
                        onTap: () => _openSpot(context, spot),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  colors.outlineVariant.withValues(alpha: 0.42),
                              width: 0.7,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumbUrl.isNotEmpty)
                                      CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          color: colors.surfaceContainerHighest,
                                          child: Icon(
                                            Icons.landscape_outlined,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: colors.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.landscape_outlined,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Material(
                                        color: colors.surface
                                            .withValues(alpha: 0.88),
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.antiAlias,
                                        child: IconButton(
                                          key: Key(
                                            'collection_remove_spot_${spot.id}',
                                          ),
                                          tooltip:
                                              'Xóa khỏi bộ sưu tập và mục Đã lưu',
                                          onPressed: () => _removeSingleSpot(
                                            context,
                                            ref,
                                            activeCollection,
                                            spot,
                                          ),
                                          constraints:
                                              const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (spot.category.isNotEmpty)
                                      Text(
                                        spot.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      spot.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 13.5,
                                          color: Colors.amber.shade600,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          spot.hasRating
                                              ? spot.ratingAvg
                                                  .toStringAsFixed(1)
                                              : '--',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            spot.priceTag,
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: spots.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}