import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/post_entity.dart';
import '../../../domain/repositories/post_repository.dart';

// Events
abstract class PostEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPostsEvent extends PostEvent {
  final bool refresh;
  LoadPostsEvent({this.refresh = false});
}

class CreatePostEvent extends PostEvent {
  final String authorId, authorName;
  final String? authorAvatar, content;
  final List<String> mediaUrls, mediaTypes;
  CreatePostEvent({
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.content,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
  });
}

class ReactToPostEvent extends PostEvent {
  final String postId, userId;
  final ReactionType? reactionType;
  ReactToPostEvent(
      {required this.postId, required this.userId, this.reactionType});
}

class SharePostEvent extends PostEvent {
  final String originalPostId, userId, userName;
  final String? userAvatar;
  SharePostEvent(
      {required this.originalPostId,
      required this.userId,
      required this.userName,
      this.userAvatar});
}

class AddCommentEvent extends PostEvent {
  final String postId, authorId, authorName, content;
  final String? authorAvatar, parentId;
  AddCommentEvent({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.parentId,
  });
}

class LikeCommentEvent extends PostEvent {
  final String postId, commentId, userId;
  LikeCommentEvent(
      {required this.postId, required this.commentId, required this.userId});
}

class SearchPostsEvent extends PostEvent {
  final String query, userId;
  SearchPostsEvent({required this.query, required this.userId});
}

// States
abstract class PostState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PostInitial extends PostState {}

class PostLoading extends PostState {}

class PostLoaded extends PostState {
  final List<PostEntity> posts;
  final bool hasMore;
  PostLoaded({required this.posts, this.hasMore = true});
  PostLoaded copyWith({List<PostEntity>? posts, bool? hasMore}) =>
      PostLoaded(posts: posts ?? this.posts, hasMore: hasMore ?? this.hasMore);
  @override
  List<Object?> get props => [posts, hasMore];
}

class PostError extends PostState {
  final String message;
  PostError(this.message);
}

// BLoC
class PostBloc extends Bloc<PostEvent, PostState> {
  final PostRepository repository;
  int _page = 1;

  PostBloc({required this.repository}) : super(PostInitial()) {
    on<LoadPostsEvent>(_onLoad);
    on<CreatePostEvent>(_onCreate);
    on<ReactToPostEvent>(_onReact);
    on<AddCommentEvent>(_onComment);
    on<LikeCommentEvent>(_onLikeComment);
    on<SearchPostsEvent>(_onSearch);
    on<SharePostEvent>(_onShare);
  }

  Future<void> _onLoad(LoadPostsEvent event, Emitter<PostState> emit) async {
    if (event.refresh) _page = 1;
    if (_page == 1) emit(PostLoading());
    try {
      final posts = await repository.getPosts(page: _page);
      final current = state is PostLoaded && !event.refresh
          ? (state as PostLoaded).posts
          : <PostEntity>[];
      _page++;
      emit(PostLoaded(
          posts: [...current, ...posts], hasMore: posts.length >= 10));
    } catch (e) {
      emit(PostError(e.toString()));
    }
  }

  Future<void> _onCreate(CreatePostEvent event, Emitter<PostState> emit) async {
    try {
      final post = await repository.createPost(
        authorId: event.authorId,
        authorName: event.authorName,
        authorAvatar: event.authorAvatar,
        content: event.content,
        mediaUrls: event.mediaUrls,
        mediaTypes: event.mediaTypes,
      );
      final current =
          state is PostLoaded ? (state as PostLoaded).posts : <PostEntity>[];
      emit(PostLoaded(posts: [post, ...current]));
    } catch (e) {
      emit(PostError(e.toString()));
    }
  }

  Future<void> _onReact(ReactToPostEvent event, Emitter<PostState> emit) async {
    try {
      final updated = await repository.reactToPost(
          event.postId, event.userId, event.reactionType);
      _updatePost(updated, emit);
    } catch (_) {}
  }

  Future<void> _onShare(SharePostEvent event, Emitter<PostState> emit) async {
    try {
      final originalPost = await repository.getPostById(event.originalPostId);
      if (originalPost == null) return;

      final post = await repository.createPost(
        authorId: event.userId,
        authorName: event.userName,
        authorAvatar: event.userAvatar,
        content: '',
        sharedPost: originalPost,
      );
      final current =
          state is PostLoaded ? (state as PostLoaded).posts : <PostEntity>[];
      emit(PostLoaded(posts: [post, ...current]));
    } catch (_) {}
  }

  Future<void> _onComment(
      AddCommentEvent event, Emitter<PostState> emit) async {
    try {
      final updated = await repository.addComment(
        postId: event.postId,
        authorId: event.authorId,
        authorName: event.authorName,
        authorAvatar: event.authorAvatar,
        content: event.content,
        parentId: event.parentId,
      );
      _updatePost(updated, emit);
    } catch (_) {}
  }

  Future<void> _onLikeComment(
      LikeCommentEvent event, Emitter<PostState> emit) async {
    try {
      final updated = await repository.likeComment(
          event.postId, event.commentId, event.userId);
      _updatePost(updated, emit);
    } catch (_) {}
  }

  Future<void> _onSearch(
      SearchPostsEvent event, Emitter<PostState> emit) async {
    // handled in SearchBloc
  }

  void _updatePost(PostEntity updated, Emitter<PostState> emit) {
    if (state is PostLoaded) {
      final posts = (state as PostLoaded)
          .posts
          .map((p) => p.id == updated.id ? updated : p)
          .toList();
      emit((state as PostLoaded).copyWith(posts: posts));
    }
  }
}
