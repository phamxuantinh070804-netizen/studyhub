import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

class UpdateUserEvent extends AuthEvent {
  final UserEntity user;
  UpdateUserEvent(this.user);
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
}
