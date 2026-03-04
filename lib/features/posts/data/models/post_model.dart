import '../../domain/entities/post_entities.dart';

class PostModel extends Post {
  PostModel({
    required int id,
    required String content,
    required int likeCount,
    String? imagePath,
    String? videoPath,
  }) : super(
    id: id,
    content: content,
    likeCount: likeCount,
    imagePath: imagePath,
    videoPath: videoPath,
  );

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      content: json['content'],
      likeCount: json['likeCount'] ?? 0,
      imagePath: json['imagePath'],
      videoPath: json['videoPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'likeCount': likeCount,
      'imagePath': imagePath,
      'videoPath': videoPath,
    };
  }
}