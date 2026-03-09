import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/friend/friend_bloc.dart';
import '../../widgets/common/avatar_widget.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<FriendBloc>().add(LoadFriendsEvent(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đoạn chat',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<FriendBloc, FriendState>(
        builder: (context, state) {
          if (state is FriendLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = state is FriendLoaded ? state.friends : [];

          if (friends.isEmpty) {
            return const Center(
              child: Text('Bạn chưa có người bạn nào để nhắn tin.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: AvatarWidget(
                  name: friend.name,
                  imageUrl: friend.avatarUrl,
                  radius: 26,
                ),
                title: Text(friend.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Nhấn để trò chuyện',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                onTap: () {
                  context.push('/chat/${friend.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
