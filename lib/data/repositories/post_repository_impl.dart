import '../../domain/entities/post_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/friend_repository.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../datasources/remote/supabase_remote_datasource.dart';

class PostRepositoryImpl implements PostRepository {
  final SupabaseRemoteDatasource remote;
  final HiveLocalDatasource local;
  PostRepositoryImpl({required this.remote, required this.local});

  @override
  Future<List<PostEntity>> getPosts({int page = 1, int limit = 10}) =>
      remote.getPosts(page: page, limit: limit);

  @override
  Future<List<PostEntity>> getUserPosts(String userId) async {
    return remote.getUserPosts(userId);
  }

  @override
  Future<PostEntity> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    PostEntity? sharedPost,
  }) =>
      remote.createPost(
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        sharedPost: sharedPost,
      );

  @override
  Future<PostEntity> toggleLikePost(String postId, String userId) =>
      remote.toggleLikePost(postId, userId);

  @override
  Future<PostEntity> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
    String? parentId,
  }) =>
      remote.addComment(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        parentId: parentId,
      );

  @override
  Future<PostEntity> likeComment(
          String postId, String commentId, String userId) =>
      remote.likeComment(postId, commentId, userId);

  @override
  Future<PostEntity?> getPostById(String postId) async {
    try {
      return await remote.getPostById(postId);
    } catch (e) {
      return local.getPostById(postId);
    }
  }

  @override
  Future<Map<String, dynamic>> search(String query, String userId) =>
      remote.search(query, userId);

  @override
  Future<void> deletePost(String postId) => remote.deletePost(postId);
}

class FriendRepositoryImpl implements FriendRepository {
  final SupabaseRemoteDatasource remote;
  final HiveLocalDatasource local;
  FriendRepositoryImpl({required this.remote, required this.local});

  @override
  Future<void> sendFriendRequest(
          {required String fromId, required String toId}) =>
      remote.sendFriendRequest(fromId, toId);

  @override
  Future<void> acceptFriendRequest(
          {required String fromId, required String toId}) =>
      remote.acceptFriendRequest(fromId, toId);

  @override
  Future<void> declineFriendRequest(
          {required String fromId, required String toId}) =>
      remote.declineFriendRequest(fromId, toId);

  @override
  Future<List<UserEntity>> getFriendRequests(String userId) async =>
      remote.getFriendRequests(userId);

  @override
  Future<List<UserEntity>> getFriends(String userId) async =>
      remote.getFriends(userId);

  @override
  Future<List<UserEntity>> getSuggestions(String userId) async =>
      remote.getSuggestions(userId);

  @override
  Future<List<NotificationEntity>> getNotifications(String userId) async =>
      remote.getNotifications(userId);

  @override
  Future<void> markNotificationRead(String id) =>
      remote.markNotificationRead(id);
}
