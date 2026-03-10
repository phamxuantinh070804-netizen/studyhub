import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/post_entity.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../../domain/entities/message_entity.dart';

class HiveLocalDatasource {
  static const String _usersBox = 'users';
  static const String _postsBox = 'posts';
  static const String _notificationsBox = 'notifications';
  static const String _messagesBox = 'messages';
  static const String _currentUserKey = 'current_user_id';
  static const String _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.openBox(_usersBox);
    await Hive.openBox(_postsBox);
    await Hive.openBox(_notificationsBox);
    await Hive.openBox(_messagesBox);
    await Hive.openBox(_settingsBox);

    final local = HiveLocalDatasource();
    if (local.getAllUsers().isEmpty && local.getAllPosts().isEmpty) {
      final admin = UserEntity(
        id: 'admin_studyhub',
        name: 'AdminStudyhub',
        email: 'admin@studyhub.vn',
        phone: null,
        avatarUrl:
            'https://ui-avatars.com/api/?name=Admin+StudyHub&background=1877F2&color=fff',
        createdAt: DateTime.now(),
        password: 'admin',
      );

      final post = PostEntity(
        id: 'welcome_post_1',
        authorId: admin.id,
        authorName: admin.name,
        authorAvatar: admin.avatarUrl,
        content:
            'Chào mừng đến với StudyHub nơi bạn có thể chia sẻ kiến thức và kinh nghiệm học tập',
        createdAt: DateTime.now(),
      );

      await local.saveUser(admin);
      await local.savePost(post);
    }
  }

  Box get _users => Hive.box(_usersBox);
  Box get _posts => Hive.box(_postsBox);
  Box get _notifications => Hive.box(_notificationsBox);
  Box get _messages => Hive.box(_messagesBox);
  Box get _settings => Hive.box(_settingsBox);

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<void> saveUser(UserEntity user) async {
    await _users.put(user.id, _userToJson(user));
  }

  Future<void> setCurrentUserId(String id) =>
      _settings.put(_currentUserKey, id);
  String? getCurrentUserId() => _settings.get(_currentUserKey);
  Future<void> clearCurrentUser() => _settings.delete(_currentUserKey);

  // ── Facebook Token ────────────────────────────────────────────────────────
  Future<void> saveFbAccessToken(String token) =>
      _settings.put('fb_access_token', token);
  String? getFbAccessToken() => _settings.get('fb_access_token');
  Future<void> clearFbAccessToken() => _settings.delete('fb_access_token');

  UserEntity? getUserById(String id) {
    final data = _users.get(id);
    if (data == null) return null;
    return _userFromJson(Map<String, dynamic>.from(data));
  }

  List<UserEntity> getAllUsers() {
    return _users.values
        .map((v) => _userFromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  UserEntity? getUserByEmailOrPhone(String value) {
    try {
      return getAllUsers()
          .firstWhere((u) => u.email == value || u.phone == value);
    } catch (_) {
      return null;
    }
  }

  // ── Posts ─────────────────────────────────────────────────────────────────
  Future<void> savePost(PostEntity post) =>
      _posts.put(post.id, _postToJson(post));

  List<PostEntity> getAllPosts() {
    final list = _posts.values
        .map((v) => _postFromJson(Map<String, dynamic>.from(v)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  PostEntity? getPostById(String id) {
    final data = _posts.get(id);
    if (data == null) return null;
    return _postFromJson(Map<String, dynamic>.from(data));
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> saveNotification(NotificationEntity n) =>
      _notifications.put(n.id, _notifToJson(n));

  List<NotificationEntity> getNotificationsForUser(String userId) {
    final list = _notifications.values
        .map((v) => _notifFromJson(Map<String, dynamic>.from(v)))
        .where((n) => n.toUserId == userId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> markNotifRead(String id) async {
    final data = _notifications.get(id);
    if (data == null) return;
    final n = _notifFromJson(Map<String, dynamic>.from(data));
    await _notifications.put(id, _notifToJson(n.copyWith(isRead: true)));
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<void> saveMessage(MessageEntity msg) =>
      _messages.put(msg.id, _messageToJson(msg));

  List<MessageEntity> getMessagesBetween(String userId1, String userId2) {
    final list = _messages.values
        .map((v) => _messageFromJson(Map<String, dynamic>.from(v)))
        .where((m) {
      final isFrom1To2 = m.senderId == userId1 && m.receiverId == userId2;
      final isFrom2To1 = m.senderId == userId2 && m.receiverId == userId1;
      return isFrom1To2 || isFrom2To1;
    }).toList();
    list.sort((a, b) =>
        a.createdAt.compareTo(b.createdAt)); // Oldest first for chat UI
    return list;
  }

  Future<void> deleteMessage(String messageId) => _messages.delete(messageId);

  // ── JSON helpers ──────────────────────────────────────────────────────────
  Map<String, dynamic> _userToJson(UserEntity u) => {
        'id': u.id,
        'name': u.name,
        'email': u.email,
        'phone': u.phone,
        'avatarUrl': u.avatarUrl,
        'coverUrl': u.coverUrl,
        'bio': u.bio,
        'location': u.location,
        'friendIds': u.friendIds,
        'pendingRequestIds': u.pendingRequestIds,
        'sentRequestIds': u.sentRequestIds,
        'createdAt': u.createdAt.toIso8601String(),
        'password': u.password ?? '',
      };

  UserEntity _userFromJson(Map<String, dynamic> m) => UserEntity(
        id: m['id'],
        name: m['name'],
        email: m['email'] ?? '',
        phone: m['phone'],
        avatarUrl: m['avatarUrl'],
        coverUrl: m['coverUrl'],
        bio: m['bio'],
        location: m['location'],
        friendIds: List<String>.from(m['friendIds'] ?? []),
        pendingRequestIds: List<String>.from(m['pendingRequestIds'] ?? []),
        sentRequestIds: List<String>.from(m['sentRequestIds'] ?? []),
        createdAt: DateTime.parse(m['createdAt']),
        password: m['password'] ?? '',
      );

  Map<String, dynamic> _postToJson(PostEntity p) => {
        'id': p.id,
        'authorId': p.authorId,
        'authorName': p.authorName,
        'authorAvatar': p.authorAvatar,
        'content': p.content,
        'mediaUrls': p.mediaUrls,
        'mediaTypes': p.mediaTypes,
        'likedByIds': p.likedByIds,
        'comments': p.comments.map((c) => _commentToJson(c)).toList(),
        'createdAt': p.createdAt.toIso8601String(),
        'isPublic': p.isPublic,
        'sharedPost': p.sharedPost != null ? _postToJson(p.sharedPost!) : null,
      };

  PostEntity _postFromJson(Map<String, dynamic> m) {
    final authorId = m['authorId'];
    final author = getUserById(authorId);
    return PostEntity(
      id: m['id'],
      authorId: authorId,
      authorName: author?.name ?? m['authorName'],
      authorAvatar: author?.avatarUrl ?? m['authorAvatar'],
      content: m['content'],
      mediaUrls: List<String>.from(m['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(m['mediaTypes'] ?? []),
      likedByIds: List<String>.from(m['likedByIds'] ?? []),
      comments: (m['comments'] as List? ?? [])
          .map((c) => _commentFromJson(Map<String, dynamic>.from(c)))
          .toList(),
      createdAt: DateTime.parse(m['createdAt']),
      isPublic: m['isPublic'] ?? true,
      sharedPost: m['sharedPost'] != null
          ? _postFromJson(Map<String, dynamic>.from(m['sharedPost']))
          : null,
    );
  }

  Map<String, dynamic> _commentToJson(CommentEntity c) => {
        'id': c.id,
        'postId': c.postId,
        'parentId': c.parentId,
        'authorId': c.authorId,
        'authorName': c.authorName,
        'authorAvatar': c.authorAvatar,
        'content': c.content,
        'likedByIds': c.likedByIds,
        'replies': c.replies.map((r) => _commentToJson(r)).toList(),
        'createdAt': c.createdAt.toIso8601String(),
      };

  CommentEntity _commentFromJson(Map<String, dynamic> m) {
    final authorId = m['authorId'];
    final author = getUserById(authorId);
    return CommentEntity(
      id: m['id'],
      postId: m['postId'],
      parentId: m['parentId'],
      authorId: authorId,
      authorName: author?.name ?? m['authorName'],
      authorAvatar: author?.avatarUrl ?? m['authorAvatar'],
      content: m['content'],
      likedByIds: List<String>.from(m['likedByIds'] ?? []),
      replies: (m['replies'] as List? ?? [])
          .map((r) => _commentFromJson(Map<String, dynamic>.from(r)))
          .toList(),
      createdAt: DateTime.parse(m['createdAt']),
    );
  }

  Map<String, dynamic> _notifToJson(NotificationEntity n) => {
        'id': n.id,
        'toUserId': n.toUserId,
        'fromUserId': n.fromUserId,
        'fromUserName': n.fromUserName,
        'fromUserAvatar': n.fromUserAvatar,
        'type': n.type.name,
        'postId': n.postId,
        'message': n.message,
        'isRead': n.isRead,
        'createdAt': n.createdAt.toIso8601String(),
      };

  NotificationEntity _notifFromJson(Map<String, dynamic> m) {
    final fromUserId = m['fromUserId'];
    final author = getUserById(fromUserId);
    return NotificationEntity(
      id: m['id'],
      toUserId: m['toUserId'],
      fromUserId: fromUserId,
      fromUserName: author?.name ?? m['fromUserName'],
      fromUserAvatar: author?.avatarUrl ?? m['fromUserAvatar'],
      type: NotificationType.values.firstWhere((t) => t.name == m['type']),
      postId: m['postId'],
      message: m['message'],
      isRead: m['isRead'],
      createdAt: DateTime.parse(m['createdAt']),
    );
  }

  Map<String, dynamic> _messageToJson(MessageEntity m) => {
        'id': m.id,
        'senderId': m.senderId,
        'receiverId': m.receiverId,
        'content': m.content,
        'createdAt': m.createdAt.toIso8601String(),
      };

  MessageEntity _messageFromJson(Map<String, dynamic> m) => MessageEntity(
        id: m['id'],
        senderId: m['senderId'],
        receiverId: m['receiverId'],
        content: m['content'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}
