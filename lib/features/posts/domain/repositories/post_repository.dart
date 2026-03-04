import '../entities/post_entities.dart';

abstract class PostRepository {
  Future<List<Post>> getPosts(int page);

  Future<void> createPost(
      String content, {
        String? imagePath,
        String? videoPath,
      });

  Future<void> likePost(int id);
}