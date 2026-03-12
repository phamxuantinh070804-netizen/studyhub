import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../data/datasources/local/hive_local_datasource.dart';
import '../../../data/datasources/remote/supabase_remote_datasource.dart';
import '../../../injection_container.dart' as di;
import 'package:flutter/foundation.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuthEvent extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String emailOrPhone;
  final String password;
  LoginEvent(this.emailOrPhone, this.password);
  @override
  List<Object?> get props => [emailOrPhone, password];
}

class RegisterEvent extends AuthEvent {
  final String name, emailOrPhone, password;
  RegisterEvent(this.name, this.emailOrPhone, this.password);
  @override
  List<Object?> get props => [name, emailOrPhone, password];
}

class LogoutEvent extends AuthEvent {}

class FacebookLoginEvent extends AuthEvent {}

class SyncDataEvent extends AuthEvent {
  final String userId;
  SyncDataEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class UpdateUserEvent extends AuthEvent {
  final UserEntity user;
  UpdateUserEvent(this.user);
  @override
  List<Object?> get props => [user];
}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final HiveLocalDatasource local;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.local,
  }) : super(AuthInitial()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginEvent>(_onLogin);
    on<RegisterEvent>(_onRegister);
    on<LogoutEvent>(_onLogout);
    on<UpdateUserEvent>(_onUpdateUser);
    on<SyncDataEvent>(_onSyncData);
    on<FacebookLoginEvent>(_onFacebookLogin);
  }

  Future<void> _onSyncData(SyncDataEvent event, Emitter<AuthState> emit) async {
    try {
      final remote = di.sl<SupabaseRemoteDatasource>();
      final posts =
          local.getAllPosts().where((p) => p.authorId == event.userId);
      for (var p in posts) {
        if (!p.id.startsWith('welcome')) {
          try {
            await remote.createPost(
              authorId: p.authorId,
              authorName: p.authorName,
              authorAvatar: p.authorAvatar,
              content: p.content,
              mediaUrls: p.mediaUrls,
              mediaTypes: p.mediaTypes,
            );
          } catch (_) {}
        }
      }

      final allUsers = local.getAllUsers();
      for (var otherUser in allUsers) {
        if (otherUser.id == event.userId) continue;
        final msgs = local.getMessagesBetween(event.userId, otherUser.id);
        for (var m in msgs) {
          try {
            await remote.sendMessage(m.senderId, m.receiverId, m.content);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  Future<void> _onCheckAuth(
      CheckAuthEvent event, Emitter<AuthState> emit) async {
    final id = local.getCurrentUserId();
    if (id != null) {
      // First emit local for fast UI
      final localUser = local.getUserById(id);
      if (localUser != null) {
        emit(AuthAuthenticated(localUser));
      }

      // Then fetch fresh data in background to stay in sync (friends, etc)
      try {
        final remote = di.sl<SupabaseRemoteDatasource>();
        final freshUser = await remote.getUserById(id);
        if (freshUser != null) {
          await local.saveUser(freshUser);
          if (!isClosed) {
            emit(AuthAuthenticated(freshUser));
          }
        }
        return;
      } catch (e) {
        debugPrint('Auth Check Error sync: $e');
        if (localUser != null) return; // stick to local if remote fails
      }
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await loginUseCase(
          emailOrPhone: event.emailOrPhone, password: event.password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await registerUseCase(
        name: event.name,
        emailOrPhone: event.emailOrPhone,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await logoutUseCase();
    emit(AuthUnauthenticated());
  }

  void _onUpdateUser(UpdateUserEvent event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  Future<void> _onFacebookLogin(
      FacebookLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // Step 1: Trigger Facebook Login with user_posts permission
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.cancelled) {
        emit(AuthUnauthenticated());
        return;
      }

      if (result.status != LoginStatus.success) {
        emit(AuthError('Đăng nhập Facebook thất bại'));
        return;
      }

      // Save FB access token for Graph API sync
      final fbAccessToken = result.accessToken?.token ?? '';
      if (fbAccessToken.isNotEmpty) {
        local.saveFbAccessToken(fbAccessToken);
      }

      // Step 2: Get user data from Facebook
      final userData = await FacebookAuth.instance.getUserData(
        fields: 'name,email,picture.width(200)',
      );

      final String fbId = userData['id'] ?? '';
      final String fbName = userData['name'] ?? 'Facebook User';
      final String fbEmail = userData['email'] ?? '$fbId@facebook.com';
      final String? fbAvatar = userData['picture']?['data']?['url'];

      // Step 3: Check if user already exists in local DB by email
      final allUsers = local.getAllUsers();
      UserEntity? existingUser;
      for (final u in allUsers) {
        if (u.email == fbEmail) {
          existingUser = u;
          break;
        }
      }

      if (existingUser != null) {
        // Update avatar from FB if needed
        final updated = existingUser.copyWith(
          avatarUrl: fbAvatar ?? existingUser.avatarUrl,
          name: existingUser.name.isEmpty ? fbName : existingUser.name,
        );
        await local.saveUser(updated);
        await local.setCurrentUserId(updated.id);
        emit(AuthAuthenticated(updated));
      } else {
        // Create new user from Facebook data
        final newUser = UserEntity(
          id: 'fb_$fbId',
          name: fbName,
          email: fbEmail,
          avatarUrl: fbAvatar,
          createdAt: DateTime.now(),
        );
        await local.saveUser(newUser);
        await local.setCurrentUserId(newUser.id);
        emit(AuthAuthenticated(newUser));
      }
    } catch (e) {
      debugPrint('Facebook Login Error: $e');
      emit(AuthError('Lỗi đăng nhập Facebook: ${e.toString()}'));
    }
  }
}
