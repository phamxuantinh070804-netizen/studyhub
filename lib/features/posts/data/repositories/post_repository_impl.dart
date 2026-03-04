import '../../domain/entities/post_entities.dart';
import '../../domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  final List<Post> _posts = [];

  @override
  Future<List<Post>> getPosts(int page) async {
    return _posts;
  }

  @override
  Future<void> createPost(
      String content, {
        String? imagePath,
        String? videoPath,
      }) async {
    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch,
      content: content,
      likeCount: 0,
      imagePath: imagePath,
      videoPath: videoPath,
    );

    _posts.insert(0, newPost);
  }

  @override
  Future<void> likePost(int id) async {
    final index = _posts.indexWhere((e) => e.id == id);

    if (index != -1) {
      final old = _posts[index];

      _posts[index] = Post(
        id: old.id,
        content: old.content,
        likeCount: old.likeCount + 1,
        imagePath: old.imagePath,
        videoPath: old.videoPath,
      );
    }
  }
}