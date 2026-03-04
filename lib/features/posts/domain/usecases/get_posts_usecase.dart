import '../entities/post_entities.dart';
import '../repositories/post_repository.dart';

class GetPostsUseCase {
  final PostRepository repository;

  GetPostsUseCase(this.repository);

  Future<List<Post>> call(int page) {
    return repository.getPosts(page);
  }
}