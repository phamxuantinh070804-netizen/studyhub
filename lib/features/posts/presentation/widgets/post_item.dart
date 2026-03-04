import 'package:flutter/material.dart';
import '../../domain/entities/post_entities.dart';

class PostItem extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;

  const PostItem({
    super.key,
    required this.post,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text(
                "Người dùng",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Content
          Text(
            post.content,
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 10),

          // Like count
          Text(
            "${post.likeCount} lượt thích",
            style: const TextStyle(color: Colors.grey),
          ),

          const Divider(),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: const Text("Thích"),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.comment_outlined),
                label: const Text("Bình luận"),
              ),
            ],
          )
        ],
      ),
    );
  }
}