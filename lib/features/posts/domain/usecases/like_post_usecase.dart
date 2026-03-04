import '../repositories/post_repository.dart';

class LikePostUseCase {
  final PostRepository repository;

  LikePostUseCase(this.repository);

  Future<void> call(int id) {
    return repository.likePost(id);
  }
}