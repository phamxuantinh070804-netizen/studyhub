import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../bloc/post_bloc.dart';
import '../bloc/post_event.dart';
import '../bloc/post_state.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  File? _selectedVideo;

  @override
  void initState() {
    super.initState();
    context.read<PostBloc>().add(LoadPostsEvent());
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _selectedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedVideo = File(picked.path);
        _selectedImage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        title: const Text(
          "StudyHub",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildCreatePostBox(),
          Expanded(
            child: BlocBuilder<PostBloc, PostState>(
              builder: (context, state) {
                return ListView.builder(
                  itemCount: state.posts.length,
                  itemBuilder: (context, index) {
                    final post = state.posts[index];
                    return _buildPostCard(post);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: () {
                  if (_controller.text.isNotEmpty ||
                      _selectedImage != null ||
                      _selectedVideo != null) {
                    context.read<PostBloc>().add(
                      CreatePostEvent(
                        _controller.text,
                        imagePath: _selectedImage?.path,
                        videoPath: _selectedVideo?.path,
                      ),
                    );

                    _controller.clear();
                    setState(() {
                      _selectedImage = null;
                      _selectedVideo = null;
                    });
                  }
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image, color: Colors.green),
                label: const Text("Photo"),
              ),
              TextButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_call, color: Colors.red),
                label: const Text("Video"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(post) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: const Text("User Name",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Just now"),
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(post.content),
            ),
          if (post.imagePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Image.file(
                File(post.imagePath!),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (post.videoPath != null)
            SizedBox(
              height: 250,
              child: VideoPlayerWidget(path: post.videoPath!),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Text("${post.likeCount} likes",
                style: const TextStyle(color: Colors.grey)),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: () {
                  context
                      .read<PostBloc>()
                      .add(LikePostEvent(post.id));
                },
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: const Text("Like"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String path;

  const VideoPlayerWidget({super.key, required this.path});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying
                ? Icons.pause
                : Icons.play_arrow,
            size: 50,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        )
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}