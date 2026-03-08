import 'package:uuid/uuid.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/post_entity.dart';
import '../../../domain/entities/notification_entity.dart';
import '../local/hive_local_datasource.dart';

const _uuid = Uuid();

class FakeRemoteDatasource {
  final HiveLocalDatasource _local;
  FakeRemoteDatasource(this._local);
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 300));

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<UserEntity> login(String emailOrPhone, String password) async {
    await _delay();
    final user = _local.getUserByEmailOrPhone(emailOrPhone);
    if (user == null) throw Exception('Tài khoản không tồn tại');
    if (user.password != password) throw Exception('Mật khẩu không đúng');
    return user;
  }

  Future<UserEntity> register(
      {required String name,
      required String emailOrPhone,
      required String password}) async {
    await _delay();
    if (_local.getUserByEmailOrPhone(emailOrPhone) != null) {
      throw Exception('Tài khoản đã tồn tại');
    }
    final user = UserEntity(
      id: _uuid.v4(),
      name: name,
      email: emailOrPhone.contains('@') ? emailOrPhone : '',
      phone: emailOrPhone.contains('@') ? null : emailOrPhone,
      createdAt: DateTime.now(),
      password: password,
    );
    await _local.saveUser(user);
    return user;
  }

  // ── Posts ─────────────────────────────────────────────────────────────────
  Future<List<PostEntity>> getPosts({int page = 1, int limit = 10}) async {
    await _delay();
    final all = _local.getAllPosts();
    final start = (page - 1) * limit;
    if (start >= all.length) return [];
    return all.skip(start).take(limit).toList();
  }

  Future<PostEntity> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    PostEntity? sharedPost,
  }) async {
    await _delay();
    final post = PostEntity(
      id: _uuid.v4(),
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      createdAt: DateTime.now(),
      sharedPost: sharedPost,
    );
    await _local.savePost(post);
    return post;
  }

  Future<PostEntity> reactToPost(
      String postId, String userId, ReactionType? type) async {
    await _delay();
    var post = _local.getPostById(postId);
    if (post == null) throw Exception('Post not found');
    final reactions = List<ReactionEntity>.from(post.reactions)
      ..removeWhere((r) => r.userId == userId);
    if (type != null) reactions.add(ReactionEntity(userId: userId, type: type));
    post = post.copyWith(reactions: reactions);
    await _local.savePost(post);
    // Notify post author
    if (type == ReactionType.like && post.authorId != userId) {
      final u = _local.getUserById(userId);
      await _local.saveNotification(NotificationEntity(
        id: _uuid.v4(),
        toUserId: post.authorId,
        fromUserId: userId,
        fromUserName: u?.name ?? '',
        fromUserAvatar: u?.avatarUrl,
        type: NotificationType.postLike,
        postId: postId,
        message: '${u?.name ?? ''} đã thích bài viết của bạn',
        createdAt: DateTime.now(),
      ));
    }
    return post;
  }

  Future<PostEntity> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
    String? parentId,
  }) async {
    await _delay();
    var post = _local.getPostById(postId);
    if (post == null) throw Exception('Post not found');
    final comment = CommentEntity(
      id: _uuid.v4(),
      postId: postId,
      parentId: parentId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      createdAt: DateTime.now(),
    );
    List<CommentEntity> comments;
    if (parentId == null) {
      comments = List<CommentEntity>.from(post.comments)..add(comment);
    } else {
      comments = post.comments.map((c) {
        if (c.id == parentId) {
          return c.copyWith(replies: [...c.replies, comment]);
        }
        return c;
      }).toList();
    }
    post = post.copyWith(comments: comments);
    await _local.savePost(post);
    if (post.authorId != authorId) {
      await _local.saveNotification(NotificationEntity(
        id: _uuid.v4(),
        toUserId: post.authorId,
        fromUserId: authorId,
        fromUserName: authorName,
        fromUserAvatar: authorAvatar,
        type: NotificationType.postComment,
        postId: postId,
        message: '$authorName đã bình luận bài viết của bạn',
        createdAt: DateTime.now(),
      ));
    }
    return post;
  }

  Future<PostEntity> likeComment(
      String postId, String commentId, String userId) async {
    await _delay();
    var post = _local.getPostById(postId);
    if (post == null) throw Exception('Post not found');
    final comments = post.comments.map((c) {
      if (c.id == commentId) {
        final likes = List<String>.from(c.likedByIds);
        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
        }
        return c.copyWith(likedByIds: likes);
      }
      // Also check replies
      final replies = c.replies.map((r) {
        if (r.id == commentId) {
          final likes = List<String>.from(r.likedByIds);
          if (likes.contains(userId)) {
            likes.remove(userId);
          } else {
            likes.add(userId);
          }
          return r.copyWith(likedByIds: likes);
        }
        return r;
      }).toList();
      return c.copyWith(replies: replies);
    }).toList();
    post = post.copyWith(comments: comments);
    await _local.savePost(post);
    return post;
  }

  // ── Friends ───────────────────────────────────────────────────────────────
  Future<void> sendFriendRequest(String fromId, String toId) async {
    await _delay();
    var from = _local.getUserById(fromId);
    var to = _local.getUserById(toId);
    if (from == null || to == null) throw Exception('User not found');
    final sent = List<String>.from(from.sentRequestIds);
    if (!sent.contains(toId)) sent.add(toId);
    final pending = List<String>.from(to.pendingRequestIds);
    if (!pending.contains(fromId)) pending.add(fromId);
    await _local.saveUser(from.copyWith(sentRequestIds: sent));
    await _local.saveUser(to.copyWith(pendingRequestIds: pending));
    await _local.saveNotification(NotificationEntity(
      id: _uuid.v4(),
      toUserId: toId,
      fromUserId: fromId,
      fromUserName: from.name,
      fromUserAvatar: from.avatarUrl,
      type: NotificationType.friendRequest,
      message: '${from.name} đã gửi lời mời kết bạn',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> acceptFriendRequest(String fromId, String toId) async {
    await _delay();
    var from = _local.getUserById(fromId);
    var to = _local.getUserById(toId);
    if (from == null || to == null) return;
    final fromFriends = List<String>.from(from.friendIds);
    final fromSent = List<String>.from(from.sentRequestIds)..remove(toId);
    if (!fromFriends.contains(toId)) fromFriends.add(toId);
    final toFriends = List<String>.from(to.friendIds);
    final toPending = List<String>.from(to.pendingRequestIds)..remove(fromId);
    if (!toFriends.contains(fromId)) toFriends.add(fromId);
    await _local.saveUser(
        from.copyWith(friendIds: fromFriends, sentRequestIds: fromSent));
    await _local.saveUser(
        to.copyWith(friendIds: toFriends, pendingRequestIds: toPending));
    await _local.saveNotification(NotificationEntity(
      id: _uuid.v4(),
      toUserId: fromId,
      fromUserId: toId,
      fromUserName: to.name,
      fromUserAvatar: to.avatarUrl,
      type: NotificationType.friendAccepted,
      message: '${to.name} đã chấp nhận lời mời kết bạn của bạn',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> declineFriendRequest(String fromId, String toId) async {
    await _delay();
    var from = _local.getUserById(fromId);
    var to = _local.getUserById(toId);
    if (from == null || to == null) return;
    await _local.saveUser(from.copyWith(
        sentRequestIds: List<String>.from(from.sentRequestIds)..remove(toId)));
    await _local.saveUser(to.copyWith(
        pendingRequestIds: List<String>.from(to.pendingRequestIds)
          ..remove(fromId)));
  }

  List<UserEntity> getFriendRequests(String userId) {
    final user = _local.getUserById(userId);
    if (user == null) return [];
    return user.pendingRequestIds
        .map((id) => _local.getUserById(id))
        .whereType<UserEntity>()
        .toList();
  }

  List<UserEntity> getFriends(String userId) {
    final user = _local.getUserById(userId);
    if (user == null) return [];
    return user.friendIds
        .map((id) => _local.getUserById(id))
        .whereType<UserEntity>()
        .toList();
  }

  List<UserEntity> getSuggestions(String userId) {
    final user = _local.getUserById(userId);
    if (user == null) return [];
    return _local
        .getAllUsers()
        .where((u) =>
            u.id != userId &&
            !user.friendIds.contains(u.id) &&
            !user.sentRequestIds.contains(u.id) &&
            !user.pendingRequestIds.contains(u.id))
        .toList();
  }

  // ── Search ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> search(
      String query, String currentUserId) async {
    await _delay();
    final q = query.toLowerCase();
    final users = _local
        .getAllUsers()
        .where((u) => u.id != currentUserId && u.name.toLowerCase().contains(q))
        .toList();
    final posts = _local
        .getAllPosts()
        .where((p) => (p.content ?? '').toLowerCase().contains(q))
        .toList();
    return {'users': users, 'posts': posts};
  }
}
