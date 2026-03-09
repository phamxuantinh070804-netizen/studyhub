import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../domain/entities/post_entity.dart';
import '../common/avatar_widget.dart';

class PostCardWidget extends StatelessWidget {
  final PostEntity post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTapAuthor;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onTapAuthor,
    required this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = post.isLikedBy(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: GestureDetector(
                onTap: onTapAuthor,
                child: AvatarWidget(
                    name: post.authorName,
                    imageUrl: post.authorAvatar,
                    radius: 20)),
            title: Text(post.authorName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Row(
              children: [
                Text(timeago.format(post.createdAt, locale: 'vi'),
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 4),
                Icon(Icons.public, size: 12, color: Colors.grey.shade600),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'delete' && onDelete != null) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa bài viết'),
                      content: const Text(
                          'Bạn có chắc chắn muốn xóa bài viết này không? Hành động này không thể hoàn tác.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDelete!();
                          },
                          child: const Text('Xóa',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                if (post.authorId == currentUserId)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa bài viết',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (post.content != null && post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(post.content!,
                  style: const TextStyle(fontSize: 15, height: 1.3)),
            ),
          if (post.mediaUrls.isNotEmpty) _buildMediaContent(),
          if (post.sharedPost != null) _buildSharedPostContent(),
          // Reaction & Comment summary
          if (post.likeCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (post.likeCount > 0) ...[
                    Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFF1877F2), shape: BoxShape.circle),
                        child: const Icon(Icons.thumb_up,
                            color: Colors.white, size: 10)),
                    const SizedBox(width: 4),
                    Text('${post.likeCount}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                  const Spacer(),
                  if (post.commentCount > 0)
                    Text('${post.commentCount} bình luận',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          Row(
            children: [
              _ActionButton(
                icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                color: isLiked ? const Color(0xFF1877F2) : Colors.grey.shade700,
                label: 'Thích',
                onTap: onLike,
              ),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Bình luận',
                onTap: onComment,
              ),
              _ActionButton(
                icon: Icons.share_outlined,
                label: 'Chia sẻ',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    return Column(
      children: List.generate(post.mediaUrls.length, (index) {
        final url = post.mediaUrls[index];
        final type =
            post.mediaTypes.length > index ? post.mediaTypes[index] : 'image';

        if (type == 'video') {
          return _VideoPlayerWidget(url: url);
        }

        return Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          child: url.startsWith('http') || url.startsWith('blob:') || kIsWeb
              ? Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => _errorIcon())
              : Image.file(File(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _errorIcon()),
        );
      }),
    );
  }

  Widget _buildSharedPostContent() {
    final shared = post.sharedPost!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: AvatarWidget(
                name: shared.authorName,
                imageUrl: shared.authorAvatar,
                radius: 16),
            title: Text(shared.authorName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(timeago.format(shared.createdAt, locale: 'vi'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          if (shared.content != null && shared.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child:
                  Text(shared.content!, style: const TextStyle(fontSize: 14)),
            ),
          if (shared.mediaUrls.isNotEmpty)
            Column(
              children: List.generate(shared.mediaUrls.length, (index) {
                final url = shared.mediaUrls[index];
                final type = shared.mediaTypes.length > index
                    ? shared.mediaTypes[index]
                    : 'image';
                if (type == 'video') return _VideoPlayerWidget(url: url);
                return url.startsWith('http')
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _errorIcon())
                    : Image.file(File(url),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _errorIcon());
              }),
            ),
        ],
      ),
    );
  }

  Widget _errorIcon() => Container(
        height: 200,
        color: Colors.grey.shade200,
        child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
      );
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});
  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.url.startsWith('http') ||
            widget.url.startsWith('blob:') ||
            kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
        : VideoPlayerController.file(File(widget.url));
    _controller.initialize().then((_) => setState(() => _initialized = true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
          height: 200,
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(alignment: Alignment.center, children: [
        VideoPlayer(_controller),
        GestureDetector(
          onTap: () => setState(() => _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play()),
          child: Icon(_controller.value.isPlaying ? null : Icons.play_arrow,
              color: Colors.white, size: 50),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
              height: 44,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color ?? Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color ?? Colors.grey.shade700, fontSize: 13)),
              ])),
        ),
      );
}
