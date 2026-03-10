import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../domain/entities/post_entity.dart';

class FacebookSyncService {
  final String accessToken;

  FacebookSyncService({required this.accessToken});

  /// Lấy danh sách bài viết gần nhất từ Facebook
  Future<List<PostEntity>> fetchFacebookPosts({
    required String fbUserId,
    required String fbUserName,
    String? fbUserAvatar,
  }) async {
    try {
      final url = Uri.parse(
        'https://graph.facebook.com/v19.0/me/feed'
        '?fields=id,message,created_time,full_picture,attachments{media,type}'
        '&limit=25'
        '&access_token=$accessToken',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('Facebook API Error: ${response.body}');
        throw Exception(
            'Không thể lấy bài viết từ Facebook (${response.statusCode})');
      }

      final data = json.decode(response.body);
      final List<dynamic> fbPosts = data['data'] ?? [];

      final List<PostEntity> posts = [];

      for (final fbPost in fbPosts) {
        final String postId = 'fb_post_${fbPost['id']}';
        final String? message = fbPost['message'];
        final String? picture = fbPost['full_picture'];
        final String createdTime = fbPost['created_time'] ?? '';

        // Parse media from attachments
        final List<String> mediaUrls = [];
        final List<String> mediaTypes = [];

        if (picture != null && picture.isNotEmpty) {
          mediaUrls.add(picture);
          mediaTypes.add('image');
        }

        // Also check attachments for videos
        final attachments = fbPost['attachments']?['data'];
        if (attachments != null) {
          for (final att in attachments) {
            final type = att['type'] ?? '';
            if (type == 'video_inline' || type == 'video') {
              final videoUrl = att['media']?['source'];
              if (videoUrl != null) {
                mediaUrls.add(videoUrl);
                mediaTypes.add('video');
              }
            }
          }
        }

        // Skip posts with no content and no media
        if ((message == null || message.isEmpty) && mediaUrls.isEmpty) {
          continue;
        }

        final post = PostEntity(
          id: postId,
          authorId: 'fb_$fbUserId',
          authorName: fbUserName,
          authorAvatar: fbUserAvatar,
          content: message,
          mediaUrls: mediaUrls,
          mediaTypes: mediaTypes,
          createdAt: DateTime.tryParse(createdTime) ?? DateTime.now(),
        );

        posts.add(post);
      }

      return posts;
    } catch (e) {
      debugPrint('FacebookSyncService Error: $e');
      rethrow;
    }
  }
}
