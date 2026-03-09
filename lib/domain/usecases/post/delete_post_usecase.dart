import '../../repositories/post_repository.dart';

class DeletePostUseCase {
  final PostRepository repository;

  DeletePostUseCase(this.repository);

  Future<void> call(String postId) async {
    return repository.deletePost(postId);
  }
}
