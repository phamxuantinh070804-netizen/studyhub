import '../models/post_model.dart';

abstract class PostRemoteDataSource {
  Future<List<PostModel>> getPosts(int page);
  Future<void> likePost(int id);
  Future<void> createPost(String content);
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  @override
  Future<List<PostModel>> getPosts(int page) async {
    await Future.delayed(const Duration(seconds: 1));

    return List.generate(
      10,
          (index) => PostModel(
        id: page * 10 + index,
        content: "Post ${page}_$index",
        likeCount: index,
        imagePath: null,
        videoPath: null,
      ),
    );
  }

  @override
  Future<void> likePost(int id) async {}

  @override
  Future<void> createPost(String content) async {}
}