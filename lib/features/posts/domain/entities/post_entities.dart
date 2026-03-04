class Post {
  final int id;
  final String content;
  final int likeCount;
  final String? imagePath;
  final String? videoPath;

  Post({
    required this.id,
    required this.content,
    required this.likeCount,
    this.imagePath,
    this.videoPath,
  });
}