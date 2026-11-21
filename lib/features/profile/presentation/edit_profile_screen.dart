import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/utils/cloudinary_url_helper.dart';
import '../domain/user_profile_model.dart';
import 'profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar(User authUser) async {
    if (_isUploadingAvatar) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);

      final secureUrl =
          await ref.read(cloudinaryServiceProvider).uploadImage(pickedFile);

      await ref.read(profileRepositoryProvider).updateUserAvatar(
            userId: authUser.uid,
            avatarUrl: secureUrl,
          );
      await authUser.updatePhotoURL(secureUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật ảnh đại diện thất bại: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _editDisplayName(User authUser, String currentName) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileFieldDialog(
        title: 'Sửa tên',
        initialValue: currentName,
        hintText: 'Nhập tên hiển thị của bạn...',
        helperText: 'Tên hiển thị dùng trên hồ sơ, bài đăng và bình luận.',
        maxLength: 40,
        maxLines: 1,
        onSave: (value) async {
          await ref.read(profileRepositoryProvider).updateDisplayName(
                userId: authUser.uid,
                displayName: value,
              );
          await authUser.updateDisplayName(value.trim());
          return value.trim();
        },
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật tên hiển thị.')),
      );
    }
  }

  Future<void> _editUsername(User authUser, String currentUsername) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileFieldDialog(
        title: 'SpotShare ID',
        initialValue: currentUsername,
        prefixText: '@',
        hintText: 'vd: teoem, trung_nguyen',
        helperText:
            'Dùng 3–20 ký tự gồm chữ thường không dấu, số, "." hoặc "_". Người khác dùng ID này để tìm kiếm bạn.',
        maxLength: 20,
        maxLines: 1,
        onSave: (value) async {
          return ref.read(profileRepositoryProvider).updateUsername(
                userId: authUser.uid,
                rawUsername: value,
              );
        },
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật SpotShare ID: @$saved')),
      );
    }
  }

  Future<void> _editBio(User authUser, String currentBio) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileFieldDialog(
        title: 'Tiểu sử',
        initialValue: currentBio,
        hintText:
            'Viết mô tả ngắn gọn để mọi người biết bạn là ai hoặc phong cách du lịch của bạn...',
        maxLength: 120,
        maxLines: 3,
        allowEmpty: true,
        onSave: (value) async {
          await ref.read(profileRepositoryProvider).updateUserBio(
                userId: authUser.uid,
                bio: value,
              );
          return value.trim();
        },
      ),
    );

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật tiểu sử.')),
      );
    }
  }

  Future<void> _copyHandle(String handle) async {
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $handle')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sửa hồ sơ')),
        body: const Center(child: Text('Vui lòng đăng nhập lại.')),
      );
    }

    final userDataStream =
        ref.watch(profileRepositoryProvider).watchUserData(authUser.uid);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pageBackground = theme.brightness == Brightness.light
        ? const Color(0xFFF6F6F6)
        : colors.surfaceContainerLowest;

    return StreamBuilder(
      stream: userDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final displayName =
            ((data['displayName'] as String?)?.trim().isNotEmpty == true)
                ? (data['displayName'] as String).trim()
                : ((authUser.displayName ?? '').trim().isNotEmpty
                    ? authUser.displayName!.trim()
                    : (authUser.email ?? 'SpotShare User').split('@').first);
        final email = (data['email'] as String?) ?? (authUser.email ?? '');
        final savedUsername =
            (data['username'] as String?)?.trim().toLowerCase() ?? '';
        final fallbackUsername = email.isNotEmpty
            ? UserProfileModel.normalizeUsername(email.split('@').first)
            : authUser.uid.substring(0, 8).toLowerCase();
        final username =
            savedUsername.isNotEmpty ? savedUsername : fallbackUsername;
        final handle = '@$username';

        final rawAvatar =
            ((data['avatarUrl'] as String?)?.trim().isNotEmpty == true)
                ? (data['avatarUrl'] as String).trim()
                : (authUser.photoURL ?? '');
        final avatarUrl = rawAvatar.isNotEmpty
            ? CloudinaryUrlHelper.feedThumbnail(rawAvatar)
            : '';
        final bio = (data['bio'] as String?)?.trim() ?? '';

        return Scaffold(
          backgroundColor: pageBackground,
          appBar: AppBar(
            backgroundColor: pageBackground,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              'Sửa hồ sơ',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingAvatar
                        ? null
                        : () => _pickAndUploadAvatar(authUser),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: colors.surfaceContainerHighest,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatarUrl.isNotEmpty
                                  ? Colors.black.withValues(alpha: 0.35)
                                  : colors.onSurface.withValues(alpha: 0.08),
                            ),
                            alignment: Alignment.center,
                            child: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt_rounded,
                                    size: 30,
                                    color: avatarUrl.isNotEmpty
                                        ? Colors.white
                                        : colors.onSurfaceVariant,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isUploadingAvatar
                        ? null
                        : () => _pickAndUploadAvatar(authUser),
                    child: Text(
                      _isUploadingAvatar ? 'Đang tải ảnh...' : 'Thay đổi ảnh',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GroupedProfileCard(
                children: [
                  _ProfileEditRow(
                    label: 'Tên',
                    value: displayName,
                    onTap: () => _editDisplayName(authUser, displayName),
                  ),
                  _ProfileEditRow(
                    label: 'SpotShare ID',
                    value: username,
                    onTap: () => _editUsername(authUser, username),
                  ),
                  _ProfileEditRow(
                    label: '',
                    value: 'spotshare.app/$handle',
                    trailingIcon: Icons.copy_rounded,
                    trailingIconSize: 18,
                    onTap: () => _copyHandle(handle),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  'Thông tin cơ bản',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              _GroupedProfileCard(
                children: [
                  _ProfileEditRow(
                    label: 'Tiểu sử',
                    value: bio.isNotEmpty
                        ? bio
                        : 'Viết mô tả ngắn gọn để cho mọi người biết bạn là ai hoặc phong cách du lịch của bạn',
                    isPlaceholder: bio.isEmpty,
                    maxLines: 4,
                    onTap: () => _editBio(authUser, bio),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupedProfileCard extends StatelessWidget {
  const _GroupedProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.6,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
    this.maxLines = 1,
    this.trailingIcon = Icons.chevron_right_rounded,
    this.trailingIconSize = 20,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;
  final int maxLines;
  final IconData trailingIcon;
  final double trailingIconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          crossAxisAlignment: maxLines > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight:
                      isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                  color: isPlaceholder
                      ? colors.onSurfaceVariant.withValues(alpha: 0.75)
                      : colors.onSurface,
                  height: 1.38,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              trailingIcon,
              size: trailingIconSize,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldDialog extends StatefulWidget {
  const _ProfileFieldDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLength,
    required this.maxLines,
    required this.onSave,
    this.prefixText,
    this.helperText,
    this.allowEmpty = false,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLength;
  final int maxLines;
  final Future<String> Function(String value) onSave;
  final String? prefixText;
  final String? helperText;
  final bool allowEmpty;

  @override
  State<_ProfileFieldDialog> createState() => _ProfileFieldDialogState();
}

class _ProfileFieldDialogState extends State<_ProfileFieldDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final value = _controller.text.trim();
    if (!widget.allowEmpty && value.isEmpty) {
      setState(() => _errorText = 'Vui lòng không để trống.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final result = await widget.onSave(value);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !_isSaving,
            autofocus: true,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              prefixText: widget.prefixText,
              hintText: widget.hintText,
              errorText: _errorText,
            ),
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.helperText!,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}