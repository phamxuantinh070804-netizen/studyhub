import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/post_entity.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../../domain/entities/message_entity.dart';

class SupabaseRemoteDatasource {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // AUTH METHODS
  // ---------------------------------------------------------------------------

  Future<UserEntity?> checkAuth() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      return getUserById(session.user.id);
    }
    return null;
  }

  Future<UserEntity> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth
          .signInWithPassword(email: email, password: password);
      if (response.user == null) throw Exception('Đăng nhập thất bại.');

      final userData = await getUserById(response.user!.id);
      if (userData != null) return userData;
      throw Exception('Không tìm thấy thông tin người dùng.');
    } on AuthException catch (e) {
      throw Exception(_translateAuthError(e.message));
    }
  }

  Future<UserEntity> register(
      String name, String email, String password) async {
    try {
      final response =
          await _supabase.auth.signUp(email: email, password: password);
      if (response.user == null) throw Exception('Đăng ký thất bại.');

      final user = UserEntity(
        id: response.user!.id,
        name: name,
        email: email,
        createdAt: DateTime.now(),
      );

      await _supabase.from('users').insert({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'created_at': user.createdAt.toIso8601String(),
      });

      return user;
    } on AuthException catch (e) {
      throw Exception(_translateAuthError(e.message));
    }
  }

  String _translateAuthError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (msg.contains('user already registered')) {
      return 'Email này đã được đăng ký.';
    }
    if (msg.contains('invalid email')) {
      return 'Định dạng email không hợp lệ.';
    }
    if (msg.contains('at least 6 characters')) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (msg.contains('rate limit') || msg.contains('after')) {
      return 'Bạn đã thao tác quá nhiều lần! Vì lý do bảo mật, vui lòng tạo tài khoản mới với một địa chỉ Email khác hoặc thử lại sau vài giờ.';
    }
    return 'Lỗi xác thực: $message';
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // PROFILE & FRIENDS METHODS
  // ---------------------------------------------------------------------------

  Future<UserEntity?> getUserById(String id) async {
    try {
      final data =
          await _supabase.from('users').select().eq('id', id).maybeSingle();
      if (data == null) return null;

      // Fetch friendship details to populate friendIds, pending, etc.
      final friendsData = await _supabase
          .from('friendships')
          .select('user_id_2')
          .eq('user_id_1', id);
      final friendIds = friendsData.map<String>((e) => e['user_id_2']).toList();

      final pendingData = await _supabase
          .from('friend_requests')
          .select('from_id')
          .eq('to_id', id);
      final pendingRequestIds =
          pendingData.map<String>((e) => e['from_id']).toList();

      final sentData = await _supabase
          .from('friend_requests')
          .select('to_id')
          .eq('from_id', id);
      final sentRequestIds = sentData.map<String>((e) => e['to_id']).toList();

      return UserEntity(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        phone: data['phone'],
        avatarUrl: data['avatar_url'],
        coverUrl: data['cover_url'],
        bio: data['bio'],
        location: data['location'],
        createdAt: DateTime.parse(data['created_at']),
        friendIds: friendIds,
        pendingRequestIds: pendingRequestIds,
        sentRequestIds: sentRequestIds,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<UserEntity>> searchUsers(String query) async {
    final data = await _supabase
        .from('users')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
    return data
        .map<UserEntity>((json) => UserEntity(
              id: json['id'],
              name: json['name'],
              email: json['email'],
              avatarUrl: json['avatar_url'],
              createdAt: DateTime.parse(json['created_at']),
            ))
        .toList();
  }

  Future<UserEntity> updateUserProfile(UserEntity user) async {
    await _supabase.from('users').update({
      'name': user.name,
      'phone': user.phone,
      'bio': user.bio,
      'location': user.location,
    }).eq('id', user.id);
    return user;
  }

  Future<String> uploadProfileImage(
      String userId, String filePath, bool isCover) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = isCover ? 'covers/$fileName' : 'avatars/$fileName';

    final Uint8List bytes = await File(filePath).readAsBytes();
    await _supabase.storage.from('media').uploadBinary(path, bytes);
    final publicUrl = _supabase.storage.from('media').getPublicUrl(path);

    await _supabase.from('users').update(
        {isCover ? 'cover_url' : 'avatar_url': publicUrl}).eq('id', userId);

    return publicUrl;
  }

  Future<String> uploadProfileImageBytes(
      String userId, Uint8List bytes, bool isCover) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = isCover ? 'covers/$fileName' : 'avatars/$fileName';

    await _supabase.storage.from('media').uploadBinary(path, bytes);
    final publicUrl = _supabase.storage.from('media').getPublicUrl(path);

    await _supabase.from('users').update(
        {isCover ? 'cover_url' : 'avatar_url': publicUrl}).eq('id', userId);

    return publicUrl;
  }

  // ---------------------------------------------------------------------------
  // POSTS && COMMENTS METHODS
  // ---------------------------------------------------------------------------

  Future<String> uploadPostMedia(String userId, String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'posts/$fileName';

    final Uint8List bytes = await File(filePath).readAsBytes();
    await _supabase.storage.from('media').uploadBinary(path, bytes);
    return _supabase.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadPostMediaBytes(
      String userId, Uint8List bytes, String ext) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'posts/$fileName';

    await _supabase.storage.from('media').uploadBinary(path, bytes);
    return _supabase.storage.from('media').getPublicUrl(path);
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
    final postInsert = await _supabase
        .from('posts')
        .insert({
          'author_id': authorId,
          'content': content,
          'media_urls': mediaUrls,
          'media_types': mediaTypes,
          'shared_post_id': sharedPost?.id,
        })
        .select()
        .single();

    return PostEntity(
      id: postInsert['id'],
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      mediaUrls: List<String>.from(postInsert['media_urls'] ?? []),
      mediaTypes: List<String>.from(postInsert['media_types'] ?? []),
      likedByIds: const [],
      comments: const [],
      createdAt: DateTime.parse(postInsert['created_at']),
      sharedPost: sharedPost,
    );
  }

  Future<PostEntity> getPostById(String postId) async {
    return _fetchPostWithComments(postId);
  }

  Future<List<PostEntity>> getPosts({int page = 1, int limit = 10}) async {
    final start = (page - 1) * limit;
    final end = start + limit - 1;

    final data = await _supabase.from('posts').select('''
      *,
      users!posts_author_id_fkey(name, avatar_url),
      comments(
        *,
        users(name, avatar_url)
      )
    ''').order('created_at', ascending: false).range(start, end);

    return data.map<PostEntity>((json) {
      final user = json['users'];
      final rawComments =
          List<Map<String, dynamic>>.from(json['comments'] ?? []);
      final parsedComments = rawComments.map((c) {
        final commentUser = c['users'];
        return CommentEntity(
          id: c['id'],
          postId: c['post_id'],
          parentId: c['parent_id'],
          authorId: c['author_id'],
          authorName: commentUser['name'] ?? 'Unknown',
          authorAvatar: commentUser['avatar_url'],
          content: c['content'],
          likedByIds: List<String>.from(c['liked_by_ids'] ?? []),
          createdAt: DateTime.parse(c['created_at']),
        );
      }).toList();

      return PostEntity(
        id: json['id'],
        authorId: json['author_id'],
        authorName: user['name'] ?? 'Unknown',
        authorAvatar: user['avatar_url'],
        content: json['content'],
        mediaUrls: List<String>.from(json['media_urls'] ?? []),
        mediaTypes: List<String>.from(json['media_types'] ?? []),
        likedByIds: List<String>.from(json['liked_by_ids'] ?? []),
        createdAt: DateTime.parse(json['created_at']),
        comments: parsedComments,
      );
    }).toList();
  }

  Future<PostEntity> toggleLikePost(String postId, String userId) async {
    // Basic array append/remove approach in SQL requires RPC or fetching first
    final postData = await _supabase
        .from('posts')
        .select('liked_by_ids, author_id')
        .eq('id', postId)
        .single();
    final likes = List<String>.from(postData['liked_by_ids'] ?? []);

    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await _supabase
        .from('posts')
        .update({'liked_by_ids': likes}).eq('id', postId);

    if (likes.contains(userId) && postData['author_id'] != userId) {
      await _supabase.from('notifications').insert({
        'to_user_id': postData['author_id'],
        'from_user_id': userId,
        'type': 'postLike',
        'post_id': postId,
        'message': 'Ai đó đã thích bài viết của bạn',
      });
    }

    final updatedData = await _supabase
        .from('posts')
        .select('*, users!posts_author_id_fkey(name, avatar_url)')
        .eq('id', postId)
        .single();
    return PostEntity(
      id: updatedData['id'],
      authorId: updatedData['author_id'],
      authorName: updatedData['users']['name'],
      authorAvatar: updatedData['users']['avatar_url'],
      content: updatedData['content'],
      mediaUrls: List<String>.from(updatedData['media_urls'] ?? []),
      mediaTypes: List<String>.from(updatedData['media_types'] ?? []),
      likedByIds: likes,
      createdAt: DateTime.parse(updatedData['created_at']),
    );
  }

  Future<PostEntity> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required String content,
    String? parentId,
  }) async {
    await _supabase.from('comments').insert({
      'post_id': postId,
      'parent_id': parentId,
      'author_id': authorId,
      'content': content,
    });

    return _fetchPostWithComments(postId); // Helper method
  }

  Future<PostEntity> likeComment(
      String postId, String commentId, String userId) async {
    final commentData = await _supabase
        .from('comments')
        .select('liked_by_ids')
        .eq('id', commentId)
        .single();
    final likes = List<String>.from(commentData['liked_by_ids'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await _supabase
        .from('comments')
        .update({'liked_by_ids': likes}).eq('id', commentId);
    return _fetchPostWithComments(postId);
  }

  Future<PostEntity> _fetchPostWithComments(String postId) async {
    final updatedData = await _supabase.from('posts').select('''
          *,
          users!posts_author_id_fkey(name, avatar_url),
          comments(
            *,
            users(name, avatar_url)
          )
        ''').eq('id', postId).single();

    final user = updatedData['users'];
    final rawComments =
        List<Map<String, dynamic>>.from(updatedData['comments'] ?? []);
    final parsedComments = rawComments.map((c) {
      final commentUser = c['users'];
      return CommentEntity(
        id: c['id'],
        postId: c['post_id'],
        parentId: c['parent_id'],
        authorId: c['author_id'],
        authorName: commentUser['name'] ?? 'Unknown',
        authorAvatar: commentUser['avatar_url'],
        content: c['content'],
        likedByIds: List<String>.from(c['liked_by_ids'] ?? []),
        createdAt: DateTime.parse(c['created_at']),
      );
    }).toList();

    return PostEntity(
      id: updatedData['id'],
      authorId: updatedData['author_id'],
      authorName: user['name'] ?? 'Unknown',
      authorAvatar: user['avatar_url'],
      content: updatedData['content'],
      mediaUrls: List<String>.from(updatedData['media_urls'] ?? []),
      mediaTypes: List<String>.from(updatedData['media_types'] ?? []),
      likedByIds: List<String>.from(updatedData['liked_by_ids'] ?? []),
      createdAt: DateTime.parse(updatedData['created_at']),
      comments: parsedComments,
    );
  }

  // ---------------------------------------------------------------------------
  // FRIENDS METHODS
  // ---------------------------------------------------------------------------

  Future<void> sendFriendRequest(String fromId, String toId) async {
    // Check if already friends
    final existingFriend = await _supabase
        .from('friendships')
        .select()
        .eq('user_id_1', fromId)
        .eq('user_id_2', toId)
        .maybeSingle();
    if (existingFriend != null) return;

    // Check if request already exists
    final existingRequest = await _supabase
        .from('friend_requests')
        .select()
        .or('and(from_id.eq.$fromId,to_id.eq.$toId),and(from_id.eq.$toId,to_id.eq.$fromId)')
        .maybeSingle();
    if (existingRequest != null) return;

    await _supabase
        .from('friend_requests')
        .insert({'from_id': fromId, 'to_id': toId});
    await _supabase.from('notifications').insert({
      'to_user_id': toId,
      'from_user_id': fromId,
      'type': 'friendRequest',
      'message': 'Bạn có một lời mời kết bạn mới',
    });
  }

  Future<void> acceptFriendRequest(String fromId, String toId) async {
    await _supabase.from('friendships').upsert([
      {'user_id_1': fromId, 'user_id_2': toId},
      {'user_id_1': toId, 'user_id_2': fromId} // Bidirectional
    ]);
    // Delete any requests between these two users in either direction
    await _supabase.from('friend_requests').delete().or(
        'and(from_id.eq.$fromId,to_id.eq.$toId),and(from_id.eq.$toId,to_id.eq.$fromId)');
  }

  Future<void> declineFriendRequest(String fromId, String toId) async {
    await _supabase.from('friend_requests').delete().or(
        'and(from_id.eq.$fromId,to_id.eq.$toId),and(from_id.eq.$toId,to_id.eq.$fromId)');
  }

  Future<void> unfriend(String userId1, String userId2) async {
    await _supabase
        .from('friendships')
        .delete()
        .inFilter('user_id_1', [userId1, userId2]).inFilter(
            'user_id_2', [userId1, userId2]);
  }

  // Simplified fetching for now
  Future<List<UserEntity>> getFriendRequests(String userId) async {
    final data = await _supabase
        .from('friend_requests')
        .select('from_id')
        .eq('to_id', userId);

    final List<UserEntity> users = [];
    for (final row in data) {
      final fromId = row['from_id'];

      // Secondary check: are they already friends?
      final isFriend = await _supabase
          .from('friendships')
          .select()
          .eq('user_id_1', userId)
          .eq('user_id_2', fromId)
          .maybeSingle();

      if (isFriend != null) {
        // Cleanup stale request if it still exists
        await _supabase
            .from('friend_requests')
            .delete()
            .eq('from_id', fromId)
            .eq('to_id', userId);
        continue;
      }

      final user = await getUserById(fromId);
      if (user != null) {
        users.add(user);
      }
    }
    return users;
  }

  Future<List<UserEntity>> getFriends(String userId) async {
    final data = await _supabase
        .from('friendships')
        .select('user_id_2')
        .eq('user_id_1', userId);

    final List<UserEntity> users = [];
    for (final row in data) {
      final user = await getUserById(row['user_id_2']);
      if (user != null) {
        users.add(user);
      }
    }
    return users;
  }

  Future<List<UserEntity>> getSuggestions(String userId) async {
    // 1. Get friend IDs
    final friendsData = await _supabase
        .from('friendships')
        .select('user_id_2')
        .eq('user_id_1', userId);
    final friendIds = friendsData.map((e) => e['user_id_2'] as String).toList();

    // 2. Get sent request IDs
    final sentData = await _supabase
        .from('friend_requests')
        .select('to_id')
        .eq('from_id', userId);
    final sentIds = sentData.map((e) => e['to_id'] as String).toList();

    // 3. Get received request IDs
    final receivedData = await _supabase
        .from('friend_requests')
        .select('from_id')
        .eq('to_id', userId);
    final receivedIds =
        receivedData.map((e) => e['from_id'] as String).toList();

    // 4. Combine all IDs to exclude
    final excludeIds = {userId, ...friendIds, ...sentIds, ...receivedIds};

    // 5. Fetch users excluding those IDs
    final allUsersData = await _supabase
        .from('users')
        .select()
        .not('id', 'in', excludeIds.toList())
        .limit(20);

    final List<UserEntity> suggestions = [];
    for (var u in allUsersData) {
      final user = await getUserById(u['id']);
      if (user != null) {
        suggestions.add(user);
      }
    }
    return suggestions;
  }

  Future<void> deletePost(String postId) async {
    // Delete comments first (foreign key constraint)
    await _supabase.from('comments').delete().eq('post_id', postId);
    await _supabase.from('posts').delete().eq('id', postId);
  }

  Future<List<PostEntity>> getUserPosts(String userId) async {
    final data = await _supabase
        .from('posts')
        .select()
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    final List<PostEntity> posts = [];
    for (final p in data) {
      final authorUser = await getUserById(p['author_id']);
      posts.add(PostEntity(
        id: p['id'],
        authorId: p['author_id'],
        authorName: authorUser?.name ?? 'Unknown',
        authorAvatar: authorUser?.avatarUrl,
        content: p['content'],
        mediaUrls: List<String>.from(p['media_urls'] ?? []),
        mediaTypes: List<String>.from(p['media_types'] ?? []),
        likedByIds: List<String>.from(p['liked_by_ids'] ?? []),
        createdAt: DateTime.parse(p['created_at']),
      ));
    }
    return posts;
  }

  // ---------------------------------------------------------------------------
  // SEARCH, NOTIFICATIONS, CHAT
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> search(
      String query, String currentUserId) async {
    if (query.trim().isEmpty) {
      return {'users': <UserEntity>[], 'posts': <PostEntity>[]};
    }

    // Search users by name
    final usersData = await _supabase
        .from('users')
        .select()
        .ilike('name', '%$query%')
        .limit(10);
    final users = usersData
        .map<UserEntity>((u) => UserEntity(
              id: u['id'],
              name: u['name'] ?? '',
              email: u['email'] ?? '',
              avatarUrl: u['avatar_url'],
              coverUrl: u['cover_url'],
              bio: u['bio'],
              createdAt: DateTime.parse(
                  u['created_at'] ?? DateTime.now().toIso8601String()),
            ))
        .toList();

    // Search posts by content
    final postsData = await _supabase
        .from('posts')
        .select()
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .limit(10);

    final List<PostEntity> posts = [];
    for (final p in postsData) {
      final authorUser = await getUserById(p['author_id']);
      posts.add(PostEntity(
        id: p['id'],
        authorId: p['author_id'],
        authorName: authorUser?.name ?? 'Unknown',
        authorAvatar: authorUser?.avatarUrl,
        content: p['content'],
        mediaUrls: List<String>.from(p['media_urls'] ?? []),
        mediaTypes: List<String>.from(p['media_types'] ?? []),
        likedByIds: List<String>.from(p['liked_by_ids'] ?? []),
        createdAt: DateTime.parse(p['created_at']),
      ));
    }

    return {'users': users, 'posts': posts};
  }

  Future<List<NotificationEntity>> getNotifications(String userId) async {
    final data = await _supabase
        .from('notifications')
        .select()
        .eq('to_user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    final List<NotificationEntity> notifications = [];
    for (final n in data) {
      final fromUser = await getUserById(n['from_user_id']);
      notifications.add(NotificationEntity(
        id: n['id'],
        toUserId: n['to_user_id'],
        fromUserId: n['from_user_id'],
        fromUserName: fromUser?.name ?? 'Unknown',
        fromUserAvatar: fromUser?.avatarUrl,
        type: _parseNotifType(n['type'] ?? ''),
        postId: n['post_id'],
        message: n['message'] ?? '',
        isRead: n['is_read'] ?? false,
        createdAt: DateTime.parse(n['created_at']),
      ));
    }
    return notifications;
  }

  NotificationType _parseNotifType(String type) {
    switch (type) {
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'friendAccepted':
        return NotificationType.friendAccepted;
      case 'postLike':
        return NotificationType.postLike;
      case 'postComment':
        return NotificationType.postComment;
      default:
        return NotificationType.friendRequest;
    }
  }

  Future<void> markNotificationRead(String notifId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notifId);
  }

  Future<List<MessageEntity>> getMessages(
      String userId1, String userId2) async {
    final data = await _supabase
        .from('messages')
        .select()
        .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
        .order('created_at', ascending: true);

    return data
        .map<MessageEntity>((m) => MessageEntity(
              id: m['id'],
              senderId: m['sender_id'],
              receiverId: m['receiver_id'],
              content: m['content'],
              createdAt: DateTime.parse(m['created_at']),
            ))
        .toList();
  }

  Future<MessageEntity> sendMessage(
      String senderId, String receiverId, String content) async {
    final data = await _supabase
        .from('messages')
        .insert({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'content': content,
        })
        .select()
        .single();

    return MessageEntity(
      id: data['id'],
      senderId: data['sender_id'],
      receiverId: data['receiver_id'],
      content: data['content'],
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);
  }
}
