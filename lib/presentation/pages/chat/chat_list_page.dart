import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../data/datasources/local/hive_local_datasource.dart';
import '../../../injection_container.dart' as di;

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final currentUser = authState.user;
    final friendIds = currentUser.friendIds;
    final local = di.sl<HiveLocalDatasource>();

    final friends = friendIds
        .map((id) => local.getUserById(id))
        .whereType<UserEntity>()
        .toList();

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
      body: friends.isEmpty
          ? const Center(
              child: Text('Bạn chưa có người bạn nào để nhắn tin.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
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
            ),
    );
  }
}
