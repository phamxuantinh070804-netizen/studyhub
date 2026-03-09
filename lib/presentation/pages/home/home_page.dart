import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/post/post_bloc.dart';
import '../../widgets/post/post_card_widget.dart';
import '../../widgets/common/avatar_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<PostBloc>().add(LoadPostsEvent(refresh: true)));
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        final s = context.read<PostBloc>().state;
        if (s is PostLoaded && s.hasMore) {
          context.read<PostBloc>().add(LoadPostsEvent());
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC9CCD1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        centerTitle: false,
        titleSpacing: 0,
        title: const Text('studyhub',
            style: TextStyle(
                color: Color(0xFF1877F2),
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.5)),
        actions: [
          _CircleButton(
              icon: Icons.add_circle,
              onTap: () => context.push('/create-post')),
          _CircleButton(
              icon: Icons.search, onTap: () => context.push('/search')),
          _CircleButton(
              icon: Icons.messenger, onTap: () => context.push('/chat')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<PostBloc>().add(LoadPostsEvent(refresh: true)),
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            children: [
              _buildCreatePostBox(),
              const Divider(height: 8, thickness: 8, color: Color(0xFFC9CCD1)),
              _buildFeedContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostBox() {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              AvatarWidget(
                  name: user?.name ?? '',
                  imageUrl: user?.avatarUrl,
                  radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/create-post'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                        'Bạn đang nghiên cứu gì thế, ${user?.name ?? ''}?',
                        style:
                            const TextStyle(color: Colors.black, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => context.push('/create-post'),
                icon: const Icon(Icons.photo_library,
                    color: Colors.green, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    return BlocBuilder<PostBloc, PostState>(
      builder: (context, state) {
        if (state is PostLoading) {
          return const Padding(
              padding: EdgeInsets.only(top: 20),
              child: CircularProgressIndicator());
        }
        if (state is PostLoaded) {
          return Column(
            children: state.posts
                .map((post) => BlocBuilder<AuthBloc, AuthState>(
                      builder: (ctx, auth) {
                        final uid =
                            auth is AuthAuthenticated ? auth.user.id : '';
                        return PostCardWidget(
                          post: post,
                          currentUserId: uid,
                          onLike: () => context.read<PostBloc>().add(
                              ToggleLikePostEvent(
                                  postId: post.id, userId: uid)),
                          onComment: () => context.push('/post/${post.id}'),
                          onTapAuthor: () =>
                              context.push('/profile/${post.authorId}'),
                          onShare: () {
                            if (auth is AuthAuthenticated) {
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
                                        context
                                            .read<PostBloc>()
                                            .add(SharePostEvent(
                                              originalPostId: post.id,
                                              userId: auth.user.id,
                                              userName: auth.user.name,
                                              userAvatar: auth.user.avatarUrl,
                                            ));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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
                          onDelete: () => context
                              .read<PostBloc>()
                              .add(DeletePostEvent(postId: post.id)),
                        );
                      },
                    ))
                .toList(),
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration:
            BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
        child: IconButton(
            icon: Icon(icon, color: Colors.black, size: 24),
            onPressed: onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
      );
}
