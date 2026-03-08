import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/post/post_bloc.dart';
import '../../../domain/entities/post_entity.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../blocs/auth/auth_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class ReelsPage extends StatelessWidget {
  const ReelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          if (state is PostLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          } else if (state is PostLoaded) {
            final videoPosts = state.posts
                .where((post) =>
                    post.mediaUrls.isNotEmpty &&
                    post.mediaTypes.contains('video'))
                .toList();

            if (videoPosts.isEmpty) {
              return const Center(
                child: Text(
                  'Chưa có thước phim nào',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: videoPosts.length,
              itemBuilder: (context, index) {
                return ReelItem(
                  post: videoPosts[index],
                  currentUserId: context.read<AuthBloc>().state
                          is AuthAuthenticated
                      ? (context.read<AuthBloc>().state as AuthAuthenticated)
                          .user
                          .id
                      : '',
                );
              },
            );
          } else if (state is PostError) {
            return Center(
                child: Text(state.message,
                    style: const TextStyle(color: Colors.red)));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final PostEntity post;
  final String currentUserId;

  const ReelItem({super.key, required this.post, required this.currentUserId});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    // Assuming the first mediaUrl is the video if mediaType is video
    final videoIndex = widget.post.mediaTypes.indexOf('video');
    final videoUrl = widget.post.mediaUrls[videoIndex >= 0 ? videoIndex : 0];

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (!_isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white54, size: 80),
            ),
          Positioned(
            left: 16,
            bottom: 24,
            width: MediaQuery.of(context).size.width * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AvatarWidget(
                      name: widget.post.authorName,
                      imageUrl: widget.post.authorAvatar,
                      radius: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.post.authorName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.post.content ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.currentUserId.isNotEmpty) {
                      context.read<PostBloc>().add(ReactToPostEvent(
                            postId: widget.post.id,
                            userId: widget.currentUserId,
                            reactionType:
                                widget.post.isLikedBy(widget.currentUserId)
                                    ? null
                                    : ReactionType.like,
                          ));
                    }
                  },
                  child: _buildActionButton(
                    widget.post.isLikedBy(widget.currentUserId)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    widget.post.likeCount.toString(),
                    color: widget.post.isLikedBy(widget.currentUserId)
                        ? Colors.red
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => context.push('/post/${widget.post.id}'),
                  child: _buildActionButton(Icons.comment_outlined,
                      widget.post.comments.length.toString()),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is AuthAuthenticated) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Chia sẻ bài viết'),
                          content: const Text(
                              'Bạn có chắc chắn muốn chia sẻ bài viết này lên trang cá nhân không?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Hủy',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                context.read<PostBloc>().add(SharePostEvent(
                                      originalPostId: widget.post.id,
                                      userId: authState.user.id,
                                      userName: authState.user.name,
                                      userAvatar: authState.user.avatarUrl,
                                    ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Đã chia sẻ bài viết thành công!')),
                                );
                              },
                              child: const Text('Chia sẻ ngay'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: _buildActionButton(Icons.share_outlined, 'Chia sẻ'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
