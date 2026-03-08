import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/friend/send_friend_request_usecase.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../injection_container.dart' as di;

// Events
abstract class FriendEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadFriendsEvent extends FriendEvent {
  final String userId;
  LoadFriendsEvent(this.userId);
}

class LoadFriendRequestsEvent extends FriendEvent {
  final String userId;
  LoadFriendRequestsEvent(this.userId);
}

class LoadSuggestionsEvent extends FriendEvent {
  final String userId;
  LoadSuggestionsEvent(this.userId);
}

class SendFriendRequestEvent extends FriendEvent {
  final String fromId, toId;
  SendFriendRequestEvent({required this.fromId, required this.toId});
}

class RespondFriendRequestEvent extends FriendEvent {
  final String fromId, toId;
  final bool accept;
  RespondFriendRequestEvent(
      {required this.fromId, required this.toId, required this.accept});
}

// States
abstract class FriendState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FriendInitial extends FriendState {}

class FriendLoading extends FriendState {}

class FriendLoaded extends FriendState {
  final List<UserEntity> friends;
  final List<UserEntity> requests;
  final List<UserEntity> suggestions;
  FriendLoaded(
      {this.friends = const [],
      this.requests = const [],
      this.suggestions = const []});
  FriendLoaded copyWith(
          {List<UserEntity>? friends,
          List<UserEntity>? requests,
          List<UserEntity>? suggestions}) =>
      FriendLoaded(
          friends: friends ?? this.friends,
          requests: requests ?? this.requests,
          suggestions: suggestions ?? this.suggestions);
  @override
  List<Object?> get props => [friends, requests, suggestions];
}

class FriendError extends FriendState {
  final String message;
  FriendError(this.message);
}

// BLoC
class FriendBloc extends Bloc<FriendEvent, FriendState> {
  final SendFriendRequestUseCase sendRequestUseCase;
  final AcceptFriendRequestUseCase acceptRequestUseCase;
  final GetFriendRequestsUseCase getFriendRequestsUseCase;
  final GetFriendsUseCase getFriendsUseCase;
  final GetSuggestionsUseCase getSuggestionsUseCase;

  FriendBloc({
    required this.sendRequestUseCase,
    required this.acceptRequestUseCase,
    required this.getFriendRequestsUseCase,
    required this.getFriendsUseCase,
    required this.getSuggestionsUseCase,
  }) : super(FriendInitial()) {
    on<LoadFriendsEvent>(_onLoadFriends);
    on<LoadFriendRequestsEvent>(_onLoadRequests);
    on<LoadSuggestionsEvent>(_onLoadSuggestions);
    on<SendFriendRequestEvent>(_onSendRequest);
    on<RespondFriendRequestEvent>(_onRespond);
  }

  Future<void> _onLoadFriends(
      LoadFriendsEvent event, Emitter<FriendState> emit) async {
    emit(FriendLoading());
    try {
      final friends = await getFriendsUseCase(event.userId);
      final requests = await getFriendRequestsUseCase(event.userId);
      final suggestions = await getSuggestionsUseCase(event.userId);
      emit(FriendLoaded(
          friends: friends, requests: requests, suggestions: suggestions));
    } catch (e) {
      emit(FriendError(e.toString()));
    }
  }

  Future<void> _onLoadRequests(
      LoadFriendRequestsEvent event, Emitter<FriendState> emit) async {
    try {
      final requests = await getFriendRequestsUseCase(event.userId);
      final current =
          state is FriendLoaded ? state as FriendLoaded : FriendLoaded();
      emit(current.copyWith(requests: requests));
    } catch (_) {}
  }

  Future<void> _onLoadSuggestions(
      LoadSuggestionsEvent event, Emitter<FriendState> emit) async {
    try {
      final suggestions = await getSuggestionsUseCase(event.userId);
      final current =
          state is FriendLoaded ? state as FriendLoaded : FriendLoaded();
      emit(current.copyWith(suggestions: suggestions));
    } catch (_) {}
  }

  Future<void> _onSendRequest(
      SendFriendRequestEvent event, Emitter<FriendState> emit) async {
    try {
      await sendRequestUseCase(fromId: event.fromId, toId: event.toId);
      final current =
          state is FriendLoaded ? state as FriendLoaded : FriendLoaded();
      // Remove from suggestions
      final suggestions =
          current.suggestions.where((u) => u.id != event.toId).toList();
      emit(current.copyWith(suggestions: suggestions));
      di.sl<AuthBloc>().add(CheckAuthEvent()); // Sync global user state
    } catch (e) {
      emit(FriendError(e.toString()));
    }
  }

  Future<void> _onRespond(
      RespondFriendRequestEvent event, Emitter<FriendState> emit) async {
    try {
      await acceptRequestUseCase(
          fromId: event.fromId, toId: event.toId, accept: event.accept);
      final current =
          state is FriendLoaded ? state as FriendLoaded : FriendLoaded();
      final requests =
          current.requests.where((u) => u.id != event.fromId).toList();
      final friends = event.accept
          ? [
              ...current.friends,
              ...current.requests.where((u) => u.id == event.fromId)
            ]
          : current.friends;
      emit(current.copyWith(requests: requests, friends: friends));
      di.sl<AuthBloc>().add(CheckAuthEvent()); // Sync global user state
    } catch (e) {
      emit(FriendError(e.toString()));
    }
  }
}
