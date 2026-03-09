import '../entities/post_entity.dart';

abstract class PostRepository {
  Future<List<PostEntity>> getPosts({int page = 1, int limit = 10});
  Future<List<PostEntity>> getUserPosts(String userId);
  Future<PostEntity> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    String? content,
    List<String> mediaUrls,
    List<String> mediaTypes,
    PostEntity? sharedPost,
  });
  Future<PostEntity> toggleLikePost(String postId, String userId);
  Future<PostEntity> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
    String? parentId,
  });
  Future<PostEntity> likeComment(
      String postId, String commentId, String userId);
  Future<PostEntity?> getPostById(String postId);
  Future<Map<String, dynamic>> search(String query, String userId);
  Future<void> deletePost(String postId);
}
