import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/post/post_bloc.dart';
import '../../blocs/friend/friend_bloc.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/post/post_card_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../data/datasources/local/hive_local_datasource.dart';
import '../../../data/datasources/remote/supabase_remote_datasource.dart';
import '../../../injection_container.dart' as di;

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  UserEntity? _profileUser;
  bool _isLoadingUser = true;
  bool _isFriend = false;
  bool _hasSent = false;
  bool _hasPending = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final local = di.sl<HiveLocalDatasource>();
    final auth = context.read<AuthBloc>().state;
    final currentUser = auth is AuthAuthenticated ? auth.user : null;
    final isMe = currentUser?.id == widget.userId;

    if (isMe) {
      if (mounted) {
        setState(() {
          _profileUser = currentUser;
          _isLoadingUser = false;
        });
      }
      return;
    }

    // Try local first
    UserEntity? user = local.getUserById(widget.userId);

    // Fetch from Supabase
    try {
      final remote = di.sl<SupabaseRemoteDatasource>();
      final fetchedUser = await remote.getUserById(widget.userId);
      if (fetchedUser != null) {
        user = fetchedUser;
        await local.saveUser(fetchedUser);
      }

      if (currentUser != null) {
        final friends = await remote.getFriends(currentUser.id);
        final requests = await remote.getFriendRequests(currentUser.id);
        final sentRequests = await remote.getFriendRequests(widget.userId);

        _isFriend = friends.any((u) => u.id == widget.userId);
        _hasPending = requests.any((u) => u.id == widget.userId);
        _hasSent = sentRequests.any((u) => u.id == currentUser.id);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }

    if (mounted) {
      setState(() {
        _profileUser = user;
        _isLoadingUser = false;
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/login');
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePhoto(bool isAvatar, UserEntity user) async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    // Upload to Supabase Storage
    final remote = di.sl<SupabaseRemoteDatasource>();
    String newUrl = '';
    try {
      final bytes = await file.readAsBytes();
      newUrl = await remote.uploadProfileImageBytes(user.id, bytes, !isAvatar);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải ảnh lên: ${e.toString()}')));
      }
      return;
    }

    final updatedUser = isAvatar
        ? user.copyWith(avatarUrl: newUrl)
        : user.copyWith(coverUrl: newUrl);

    // Save to Hive for fast local caching
    final local = di.sl<HiveLocalDatasource>();
    await local.saveUser(updatedUser);

    // Update AuthBloc state so UI updates everywhere
    if (mounted) {
      context.read<AuthBloc>().add(UpdateUserEvent(updatedUser));
      // Refresh feed posts to grab the new avatar!
      context.read<PostBloc>().add(LoadPostsEvent(refresh: true));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = context.watch<AuthBloc>().state;
    final currentUser = auth is AuthAuthenticated ? auth.user : null;
    final isMe = currentUser?.id == widget.userId;

    // Use current user from auth state if it's "me" to ensure live updates
    final displayUser = isMe ? currentUser! : _profileUser;

    if (displayUser == null) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy người dùng')));
    }

    bool isFriend = isMe ? false : _isFriend;
    bool hasSent = isMe ? false : _hasSent;
    bool hasPending = isMe ? false : _hasPending;

    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      body: CustomScrollView(slivers: [
        // Cover photo + profile header
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppTheme.white,
          elevation: 0,
          leading: Center(
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  }),
            ),
          ),
          actions: [
            Center(
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz,
                      color: Colors.white, size: 20),
                  onSelected: (value) {
                    if (value == 'logout') _showLogoutDialog(context);
                    if (value == 'update_cover' && isMe) {
                      _updatePhoto(false, displayUser);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isMe) ...[
                      const PopupMenuItem(
                        value: 'update_cover',
                        child: Row(children: [
                          Icon(Icons.camera_alt_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Đổi ảnh bìa'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(children: [
                          Icon(Icons.logout, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Đăng xuất',
                              style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                    const PopupMenuItem(
                        value: 'copy',
                        child: Row(children: [
                          Icon(Icons.link, size: 20),
                          SizedBox(width: 8),
                          Text('Sao chép liên kết'),
                        ])),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              GestureDetector(
                onTap:
                    null, // Vô hiệu hóa đổi ảnh trực tiếp, dùng nút Chỉnh sửa
                child: Container(
                  color: Colors.grey.shade300,
                  child: displayUser.coverUrl != null
                      ? ((displayUser.coverUrl!.startsWith('http') ||
                              displayUser.coverUrl!.startsWith('blob:') ||
                              kIsWeb)
                          ? Image.network(displayUser.coverUrl!,
                              fit: BoxFit.cover)
                          : Image.file(File(displayUser.coverUrl!),
                              fit: BoxFit.cover))
                      : const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                              Color(0xFF1877F2),
                              Color(0xFF166FE5)
                            ]))),
                ),
              ),
              // Avatar positioned at bottom left
              Positioned(
                bottom: 0,
                left: 16,
                child: GestureDetector(
                  onTap:
                      null, // Vô hiệu hóa đổi ảnh trực tiếp, dùng nút Chỉnh sửa
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4)),
                    child: Stack(
                      children: [
                        AvatarWidget(
                            name: displayUser.name,
                            imageUrl: displayUser.avatarUrl,
                            radius: 44),
                        if (isMe)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.black87),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Profile info
        SliverToBoxAdapter(
            child: Container(
          color: AppTheme.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayUser.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${displayUser.friendIds.length} bạn bè',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            if (displayUser.bio != null) ...[
              const SizedBox(height: 8),
              Text(displayUser.bio!, style: const TextStyle(fontSize: 15)),
            ],
            const SizedBox(height: 12),
            if (isMe)
              Row(children: [
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () => context.push('/create-post'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Đăng bài'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: AppTheme.primaryBlue),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera),
                            title: const Text('Chỉnh sửa ảnh đại diện'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _updatePhoto(true, displayUser);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo),
                            title: const Text('Chỉnh sửa ảnh bìa'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _updatePhoto(false, displayUser);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18, color: Colors.black87),
                  label: const Text('Chỉnh sửa',
                      style: TextStyle(color: Colors.black87)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      minimumSize: const Size(0, 40),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6))),
                )),
              ])
            else
              _buildFriendActions(context, displayUser, currentUser, isFriend,
                  hasSent, hasPending),
          ]),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        BlocBuilder<PostBloc, PostState>(builder: (context, ps) {
          if (ps is! PostLoaded) {
            return const SliverToBoxAdapter(child: SizedBox());
          }
          final userPosts =
              ps.posts.where((p) => p.authorId == widget.userId).toList();
          if (userPosts.isEmpty) {
            return SliverToBoxAdapter(
                child: Container(
                    color: AppTheme.white,
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                        child: Text('Chưa có bài viết nào',
                            style: TextStyle(color: AppTheme.textGrey)))));
          }
          return SliverList(
              delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PostCardWidget(
                post: userPosts[i],
                currentUserId: currentUser?.id ?? '',
                onLike: () => context.read<PostBloc>().add(ToggleLikePostEvent(
                    postId: userPosts[i].id, userId: currentUser?.id ?? '')),
                onComment: () => context.push('/post/${userPosts[i].id}'),
                onTapAuthor: () {},
                onShare: () {
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
                                    originalPostId: userPosts[i].id,
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
                onDelete: () => context
                    .read<PostBloc>()
                    .add(DeletePostEvent(postId: userPosts[i].id)),
              ),
            ),
            childCount: userPosts.length,
          ));
        }),
      ]),
    );
  }

  Widget _buildFriendActions(BuildContext context, UserEntity profileUser,
      UserEntity? currentUser, bool isFriend, bool hasSent, bool hasPending) {
    if (isFriend) {
      return Row(children: [
        Expanded(
            child: ElevatedButton.icon(
                onPressed: () => context.push('/chat/${profileUser.id}'),
                icon: const Icon(Icons.messenger_outline),
                label: const Text('Nhắn tin'))),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.people_outline),
                label: const Text('Bạn bè'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark))),
      ]);
    }
    if (hasPending) {
      return Row(children: [
        Expanded(
            child: ElevatedButton(
                onPressed: () {
                  context.read<FriendBloc>().add(RespondFriendRequestEvent(
                      fromId: profileUser.id,
                      toId: currentUser!.id,
                      accept: true));
                  context
                      .read<NotificationBloc>()
                      .add(LoadNotificationsEvent(currentUser.id));
                },
                child: const Text('Chấp nhận'))),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton(
                onPressed: () {
                  context.read<FriendBloc>().add(RespondFriendRequestEvent(
                      fromId: profileUser.id,
                      toId: currentUser!.id,
                      accept: false));
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark),
                child: const Text('Từ chối'))),
      ]);
    }

    return Row(children: [
      Expanded(
          child: ElevatedButton.icon(
        onPressed: hasSent
            ? null
            : () {
                context.read<FriendBloc>().add(SendFriendRequestEvent(
                    fromId: currentUser!.id, toId: profileUser.id));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã gửi lời mời kết bạn'),
                    behavior: SnackBarBehavior.floating));
              },
        icon: Icon(hasSent ? Icons.check : Icons.person_add),
        label: Text(hasSent ? 'Đã gửi lời mời' : 'Thêm bạn bè'),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSent ? Colors.grey : AppTheme.primaryBlue,
        ),
      )),
      const SizedBox(width: 8),
      Expanded(
          child: OutlinedButton.icon(
              onPressed: () => context.push('/chat/${profileUser.id}'),
              icon: const Icon(Icons.messenger_outline),
              label: const Text('Nhắn tin'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark))),
    ]);
  }
}
