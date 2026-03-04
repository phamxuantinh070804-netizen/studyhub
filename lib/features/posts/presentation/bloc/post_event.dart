abstract class PostEvent {}

class LoadPostsEvent extends PostEvent {}

class CreatePostEvent extends PostEvent {
  final String content;
  final String? imagePath;
  final String? videoPath;

  CreatePostEvent(
      this.content, {
        this.imagePath,
        this.videoPath,
      });
}

class LikePostEvent extends PostEvent {
  final int id;

  LikePostEvent(this.id);
}