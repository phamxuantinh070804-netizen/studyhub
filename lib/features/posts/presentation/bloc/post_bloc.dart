import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/post_repository.dart';
import 'post_event.dart';
import 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  final PostRepository repository;

  PostBloc(this.repository) : super(PostState()) {
    on<LoadPostsEvent>(_load);
    on<CreatePostEvent>(_create);
    on<LikePostEvent>(_like);
  }

  Future<void> _load(
      LoadPostsEvent event, Emitter<PostState> emit) async {
    final posts = await repository.getPosts(1);
    emit(PostState(posts: List.from(posts)));
  }

  Future<void> _create(
      CreatePostEvent event, Emitter<PostState> emit) async {
    await repository.createPost(
      event.content,
      imagePath: event.imagePath,
      videoPath: event.videoPath,
    );

    final posts = await repository.getPosts(1);
    emit(PostState(posts: List.from(posts)));
  }

  Future<void> _like(
      LikePostEvent event, Emitter<PostState> emit) async {
    await repository.likePost(event.id);

    final posts = await repository.getPosts(1);
    emit(PostState(posts: List.from(posts)));
  }
}