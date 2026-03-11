import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FacebookApi {
  // ✅ ĐÃ SỬA: ID chuẩn của Fanpage TAROT TO KEY
  static const String _pageId = '630344643494436';

  // ✅ Token vĩnh viễn của bạn
  static const String _pageAccessToken =
      'EAAcxgVOuK7ABQZCLJ06WnaP4dtxZCDCU9scJRFNpQ1NNHr6sveaSRRQO1PutEdmOs9dobQnaYuyVtZA6UmpCQPYjr34N2qg61Eko2bOSJw49sBCLlbZALOsfzUiuxOGjNZAq9KHFskwm0QXkZBD6AZAmsfJJFYdCNA5khORRs9kdecRi0yQ5q3ZBwZAzzYZBzwwYMHZAVDB';

  /// Hàm gửi bài viết lên Fanpage (hỗ trợ cả văn bản, hình ảnh và video)
  static Future<bool> postToFanpage(String message,
      {List<String>? mediaPaths, List<String>? mediaTypes}) async {
    try {
      debugPrint('🚀 Đang chuẩn bị đăng bài lên Facebook Fanpage...');

      final List<String> mediaIds = [];

      // 1. Nếu có media, tải chúng lên trước dưới dạng unpublished
      if (mediaPaths != null &&
          mediaTypes != null &&
          mediaPaths.isNotEmpty &&
          mediaPaths.length == mediaTypes.length) {
        for (int i = 0; i < mediaPaths.length; i++) {
          final id = await _uploadMedia(mediaPaths[i], mediaTypes[i]);
          if (id != null) {
            mediaIds.add(id);
          }
        }
      }

      // 2. Đăng bài lên feed
      final Uri url = Uri.parse('https://graph.facebook.com/v19.0/$_pageId/feed');

      final Map<String, String> body = {
        'message': message,
        'access_token': _pageAccessToken,
      };

      // Nếu có mediaIds, thêm vào tham số attached_media
      if (mediaIds.isNotEmpty) {
        final List<Map<String, String>> attachedMedia =
            mediaIds.map((id) => {'media_fbid': id}).toList();
        body['attached_media'] = jsonEncode(attachedMedia);
      }

      final response = await http.post(url, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Đăng bài lên TAROT TO KEY thành công!');
        debugPrint('🆔 ID bài viết: ${data['id']}');
        return true;
      } else {
        debugPrint('❌ Lỗi từ Facebook Server (Feed): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi xử lý đăng bài: $e');
      return false;
    }
  }

  /// Hàm phụ để tải media lên Facebook ( unpublished )
  static Future<String?> _uploadMedia(String path, String type) async {
    final bool isVideo = type == 'video';
    final String endpoint = isVideo ? 'videos' : 'photos';
    // Video upload thường dùng graph-video.facebook.com nhưng graph.facebook.com vẫn hoạt động cho upload đơn giản
    final Uri url = Uri.parse('https://graph.facebook.com/v19.0/$_pageId/$endpoint');

    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['access_token'] = _pageAccessToken;
      request.fields['published'] = 'false'; // Quan trọng: chỉ upload, không đăng ngay

      if (isVideo) {
        request.fields['description'] = 'Video upload from app';
      }

      request.files.add(await http.MultipartFile.fromPath(
        isVideo ? 'source' : 'source', // Cả video và photo đều dùng 'source' hoặc 'file' tùy API, nhưng v19 page photo dùng 'source'
        path,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id']?.toString();
      } else {
        debugPrint('❌ Lỗi tải $type lên Facebook: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi kết nối khi tải media: $e');
      return null;
    }
  }
}
