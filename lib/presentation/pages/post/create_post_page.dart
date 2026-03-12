import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/post/post_bloc.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../../data/datasources/remote/supabase_remote_datasource.dart';
import '../../../injection_container.dart' as di;

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _mediaPaths = [];
  final List<String> _mediaTypes = [];
  bool _loading = false;
  bool _shareToFb = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canPost => _ctrl.text.trim().isNotEmpty || _mediaPaths.isNotEmpty;

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      setState(() {
        for (final f in files) {
          _mediaPaths.add(f.path);
          _mediaTypes.add('image');
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (file != null) {
      setState(() {
        _mediaPaths.add(file.path);
        _mediaTypes.add('video');
      });
    }
  }

  Future<void> _takePhoto() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) {
      setState(() {
        _mediaPaths.add(file.path);
        _mediaTypes.add('image');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;

    return Scaffold(
      backgroundColor: Colors.white,
      // Đã bỏ AppBar truyền thống để tự tạo thanh điều hướng thấp hơn tránh đốm đen màn hình
      body: SafeArea(
        child: Column(
          children: [
            // Thanh điều hướng tự chế (thấp hơn appBar cũ)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.black, size: 30),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Tạo bài viết',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Nút Đăng nổi bật hơn
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: (_loading || !_canPost) ? null : _post,
                      style: TextButton.styleFrom(
                        backgroundColor: _canPost
                            ? const Color(0xFF1877F2)
                            : Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('ĐĂNG',
                              style: TextStyle(
                                  color: _canPost
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Profile
                    Row(
                      children: [
                        AvatarWidget(
                            name: user?.name ?? '',
                            imageUrl: user?.avatarUrl,
                            radius: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.public,
                                      size: 14, color: Color(0xFF65676B)),
                                  SizedBox(width: 4),
                                  Text('Công khai',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF65676B))),
                                  Icon(Icons.arrow_drop_down,
                                      size: 16, color: Color(0xFF65676B)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Text Input
                    TextField(
                      controller: _ctrl,
                      maxLines: null,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText:
                            'Bạn đang nghiên cứu gì thế, ${user?.name ?? ''}?',
                        hintStyle:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 18),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Media Preview
                    if (_mediaPaths.isNotEmpty) _buildMediaPreview(),
                    const SizedBox(height: 16),
                    // Facebook share toggle
                    _buildFacebookToggle(),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            _buildBottomToolBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_mediaPaths.isEmpty) return const SizedBox.shrink();

    if (_mediaPaths.length == 1) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              width: double.infinity,
              color: Colors.grey.shade100,
              child: _mediaTypes[0] == 'video'
                  ? Container(
                      color: Colors.black,
                      child: const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Colors.white, size: 50)))
                  : (kIsWeb
                      ? Image.network(_mediaPaths[0],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity)
                      : Image.file(File(_mediaPaths[0]),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity)),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _mediaPaths.removeAt(0);
                _mediaTypes.removeAt(0);
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _mediaPaths.length == 2 ? 2 : 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: _mediaPaths.length,
      itemBuilder: (_, i) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _mediaTypes[i] == 'video'
                ? Container(
                    color: Colors.black,
                    child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 30)))
                : (kIsWeb
                    ? Image.network(_mediaPaths[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity)
                    : Image.file(File(_mediaPaths[i]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity)),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() {
                _mediaPaths.removeAt(i);
                _mediaTypes.removeAt(i);
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacebookToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _shareToFb ? const Color(0xFFE7F3FF) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _shareToFb ? const Color(0xFF1877F2) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.facebook,
              color: _shareToFb ? const Color(0xFF1877F2) : Colors.grey,
              size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chia sẻ lên Facebook',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color:
                        _shareToFb ? const Color(0xFF1877F2) : Colors.black87,
                  ),
                ),
                Text(
                  'Tự động mở chia sẻ sau khi đăng',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _shareToFb,
            onChanged: (v) => setState(() => _shareToFb = v),
            activeTrackColor: const Color(0xFF1877F2),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          const Text('Thêm vào bài viết',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          _ToolIcon(
              icon: Icons.photo_library,
              color: Colors.green,
              onTap: _pickImages),
          _ToolIcon(icon: Icons.videocam, color: Colors.red, onTap: _pickVideo),
          _ToolIcon(
              icon: Icons.camera_alt, color: Colors.blue, onTap: _takePhoto),
          _ToolIcon(icon: Icons.more_horiz, color: Colors.grey, onTap: () {}),
        ],
      ),
    );
  }

  Future<void> _post() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() => _loading = true);

    try {
      // Upload media files to Supabase Storage first
      final remote = di.sl<SupabaseRemoteDatasource>();
      final List<String> uploadedUrls = [];

      for (int i = 0; i < _mediaPaths.length; i++) {
        final xFile = XFile(_mediaPaths[i]);
        final bytes = await xFile.readAsBytes();
        final ext = _mediaPaths[i].split('.').last.toLowerCase();
        final url = await remote.uploadPostMediaBytes(auth.user.id, bytes, ext);
        uploadedUrls.add(url);
      }

      if (!mounted) return;

      context.read<PostBloc>().add(CreatePostEvent(
            authorId: auth.user.id,
            authorName: auth.user.name,
            authorAvatar: auth.user.avatarUrl,
            content: _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim(),
            mediaUrls: uploadedUrls,
            mediaTypes: _mediaTypes,
            shareToFacebook: _shareToFb,
          ));

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() => _loading = false);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng bài: ${e.toString()}')),
        );
      }
    }
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ToolIcon(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(),
    );
  }
}
