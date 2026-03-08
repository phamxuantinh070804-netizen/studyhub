import 'dart:io';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../domain/entities/post_entity.dart';
import '../common/avatar_widget.dart';

typedef ReactionCallback = void Function(ReactionType? type);

class PostCardWidget extends StatelessWidget {
  final PostEntity post;
  final String currentUserId;
  final ReactionCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onTapAuthor;
  final VoidCallback onShare;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onReact,
    required this.onComment,
    required this.onTapAuthor,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final myReaction = post.reactionOf(currentUserId);

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
            trailing: const Icon(Icons.more_horiz),
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
                    _buildReactionSummary(post),
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
              _ReactionButton(
                myReaction: myReaction,
                onReact: onReact,
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

  Widget _buildReactionSummary(PostEntity post) {
    final counts = post.reactionCounts;
    final sortedReactions = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top3 = sortedReactions.take(3).map((e) => e.key).toList();

    return SizedBox(
      height: 20,
      width: (top3.length * 14.0) + 4.0,
      child: Stack(
        children: List.generate(top3.length, (index) {
          return Positioned(
            left: index * 12.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: _getReactionIcon(top3[index]),
            ),
          );
        }),
      ),
    );
  }

  Widget _getReactionIcon(ReactionType t) {
    switch (t) {
      case ReactionType.like:
        return const CircleAvatar(
            radius: 8,
            backgroundColor: Color(0xFF1877F2),
            child: Icon(Icons.thumb_up, color: Colors.white, size: 10));
      case ReactionType.love:
        return const CircleAvatar(
            radius: 8,
            backgroundColor: Colors.red,
            child: Icon(Icons.favorite, color: Colors.white, size: 10));
      case ReactionType.haha:
        return const Text('😆', style: TextStyle(fontSize: 14));
      case ReactionType.wow:
        return const Text('😮', style: TextStyle(fontSize: 14));
      case ReactionType.sad:
        return const Text('😢', style: TextStyle(fontSize: 14));
      case ReactionType.angry:
        return const Text('😡', style: TextStyle(fontSize: 14));
    }
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
          child: url.startsWith('http')
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

class _ReactionButton extends StatefulWidget {
  final ReactionType? myReaction;
  final ReactionCallback onReact;

  const _ReactionButton({required this.myReaction, required this.onReact});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  OverlayEntry? _overlay;

  void _showPicker(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: 20,
        bottom: MediaQuery.of(context).size.height - offset.dy + 10,
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pickerIcon('👍', ReactionType.like),
                _pickerIcon('❤️', ReactionType.love),
                _pickerIcon('😆', ReactionType.haha),
                _pickerIcon('😮', ReactionType.wow),
                _pickerIcon('😢', ReactionType.sad),
                _pickerIcon('😡', ReactionType.angry),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  Widget _pickerIcon(String emoji, ReactionType t) {
    return GestureDetector(
      onTap: () {
        widget.onReact(t);
        _overlay?.remove();
        _overlay = null;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(emoji, style: const TextStyle(fontSize: 30)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reaction = widget.myReaction;
    final label = _getLabel(reaction);
    final color = _getColor(reaction);

    Widget reactionWidget;
    if (reaction == null) {
      reactionWidget = Icon(Icons.thumb_up_outlined, color: color, size: 20);
    } else if (reaction == ReactionType.like) {
      reactionWidget = Icon(Icons.thumb_up, color: color, size: 20);
    } else if (reaction == ReactionType.love) {
      reactionWidget = Icon(Icons.favorite, color: color, size: 20);
    } else {
      reactionWidget =
          Text(_getEmoji(reaction), style: const TextStyle(fontSize: 18));
    }

    return Expanded(
      child: GestureDetector(
        onLongPress: () => _showPicker(context),
        onTap: () =>
            widget.onReact(reaction != null ? null : ReactionType.like),
        child: Container(
          height: 44,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              reactionWidget,
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _getEmoji(ReactionType t) {
    switch (t) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.haha:
        return '😆';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😡';
    }
  }

  String _getLabel(ReactionType? t) {
    if (t == null) return 'Thích';
    switch (t) {
      case ReactionType.like:
        return 'Thích';
      case ReactionType.love:
        return 'Yêu thích';
      case ReactionType.haha:
        return 'Haha';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Buồn';
      case ReactionType.angry:
        return 'Phẫn nộ';
    }
  }

  Color _getColor(ReactionType? t) {
    if (t == null) return Colors.grey.shade700;
    if (t == ReactionType.like) return const Color(0xFF1877F2);
    if (t == ReactionType.love) return Colors.red;
    return Colors.orange;
  }
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
    _controller = widget.url.startsWith('http')
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
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
              height: 44,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ])),
        ),
      );
}
