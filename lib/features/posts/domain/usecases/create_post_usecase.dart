import '../repositories/post_repository.dart';

class CreatePostUseCase {
  final PostRepository repository;

  CreatePostUseCase(this.repository);

  Future<void> call(String content) {
    return repository.createPost(content);
  }
}