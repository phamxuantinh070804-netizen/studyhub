import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FacebookApi {
  // ID Fanpage TAROT TO KEY của bạn
  static const String _pageId = '2024756361440176';

  // Token "Không bao giờ hết hạn" bạn vừa lấy được (Dán toàn bộ mã xanh vào đây)
  static const String _pageAccessToken = 'EAAcxgVOuK7ABQZCLJ06WnaP4dtxZCDCU9scJRFNpQ1NNHr6sveaSRRQO1PutEdmOs9dobQnaYuyVtZA6UmpCQPYjr34N2qg61Eko2bOSJw49sBCLlbZALOsfzUiuxOGjNZAq9KHFskwm0QXkZBD6AZAmsfJJFYdCNA5khORRs9kdecRi0yQ5q3ZBwZAzzYZBzwwYMHZAVDB';

  /// Hàm gửi bài viết lên Fanpage
  static Future<bool> postToFanpage(String message) async {
    final Uri url = Uri.parse('https://graph.facebook.com/v19.0/$_pageId/feed');

    try {
      debugPrint('🚀 Đang gửi bài lên Fanpage TAROT TO KEY...');

      final response = await http.post(
        url,
        body: {
          'message': message,
          'access_token': _pageAccessToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Đăng thành công! ID bài viết: ${data['id']}');
        return true;
      } else {
        debugPrint('❌ Lỗi Facebook: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Lỗi kết nối: $e');
      return false;
    }
  }
}
