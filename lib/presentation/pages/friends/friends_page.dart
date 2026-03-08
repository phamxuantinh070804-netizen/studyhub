import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/friend/friend_bloc.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        context.read<FriendBloc>().add(LoadFriendsEvent(authState.user.id));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      appBar: AppBar(
        title:
            const Text('Bạn bè', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Lời mời'),
            Tab(text: 'Gợi ý'),
            Tab(text: 'Bạn bè'),
          ],
        ),
      ),
      body: BlocBuilder<FriendBloc, FriendState>(
        builder: (context, state) {
          if (state is FriendLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = state is FriendLoaded ? state : FriendLoaded();
          return TabBarView(
            controller: _tabController,
            children: [
              _RequestsTab(requests: loaded.requests),
              _SuggestionsTab(suggestions: loaded.suggestions),
              _FriendsTab(friends: loaded.friends),
            ],
          );
        },
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final List<UserEntity> requests;
  const _RequestsTab({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Không có lời mời kết bạn nào',
              style: TextStyle(color: AppTheme.textGrey)),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: requests.length,
      itemBuilder: (context, i) => _FriendCard(
        user: requests[i],
        isRequest: true,
        onAccept: () {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated) {
            context.read<FriendBloc>().add(RespondFriendRequestEvent(
                  fromId: requests[i].id,
                  toId: authState.user.id,
                  accept: true,
                ));
            context
                .read<NotificationBloc>()
                .add(LoadNotificationsEvent(authState.user.id));
          }
        },
        onDecline: () {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated) {
            context.read<FriendBloc>().add(RespondFriendRequestEvent(
                  fromId: requests[i].id,
                  toId: authState.user.id,
                  accept: false,
                ));
          }
        },
      ),
    );
  }
}

class _SuggestionsTab extends StatelessWidget {
  final List<UserEntity> suggestions;
  const _SuggestionsTab({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Không có gợi ý nào',
              style: TextStyle(color: AppTheme.textGrey)),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, i) => _FriendCard(
        user: suggestions[i],
        onAdd: () {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated) {
            context.read<FriendBloc>().add(SendFriendRequestEvent(
                  fromId: authState.user.id,
                  toId: suggestions[i].id,
                ));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Đã gửi lời mời đến ${suggestions[i].name}')),
            );
          }
        },
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  final List<UserEntity> friends;
  const _FriendsTab({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Chưa có bạn bè nào',
              style: TextStyle(color: AppTheme.textGrey)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(
            color: AppTheme.white, borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          leading: GestureDetector(
              onTap: () => context.push('/profile/${friends[i].id}'),
              child: AvatarWidget(
                  name: friends[i].name,
                  imageUrl: friends[i].avatarUrl,
                  radius: 24)),
          title: GestureDetector(
              onTap: () => context.push('/profile/${friends[i].id}'),
              child: Text(friends[i].name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          subtitle: Text('${friends[i].friendIds.length} bạn bè',
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          trailing: TextButton(
            onPressed: () => context.push('/chat/${friends[i].id}'),
            child: const Text('Nhắn tin'),
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatefulWidget {
  final UserEntity user;
  final bool isRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onAdd;

  const _FriendCard({
    required this.user,
    this.isRequest = false,
    this.onAccept,
    this.onDecline,
    this.onAdd,
  });

  @override
  State<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<_FriendCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => context.push('/profile/${widget.user.id}'),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: AvatarWidget(
                        name: widget.user.name,
                        imageUrl: widget.user.avatarUrl,
                        radius: 44),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => context.push('/profile/${widget.user.id}'),
                    child: Text(widget.user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.isRequest) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: widget.onAccept,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Xác nhận'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: OutlinedButton(
                        onPressed: widget.onDecline,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: AppTheme.borderColor),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Xóa',
                            style: TextStyle(color: AppTheme.textDark)),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: widget.user.hasPendingRequestFrom(context
                                      .watch<AuthBloc>()
                                      .state is AuthAuthenticated
                                  ? (context.watch<AuthBloc>().state
                                          as AuthAuthenticated)
                                      .user
                                      .id
                                  : '') ||
                              widget.user.hasSentRequestTo(context
                                      .watch<AuthBloc>()
                                      .state is AuthAuthenticated
                                  ? (context.watch<AuthBloc>().state
                                          as AuthAuthenticated)
                                      .user
                                      .id
                                  : '')
                          ? OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Đã gửi/Chờ phản hồi'),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                widget.onAdd?.call();
                              },
                              icon: const Icon(Icons.person_add, size: 14),
                              label: const Text('Thêm bạn'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
