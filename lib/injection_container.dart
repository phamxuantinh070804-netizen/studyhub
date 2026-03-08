import 'package:get_it/get_it.dart';
import 'data/datasources/local/hive_local_datasource.dart';
import 'data/datasources/remote/fake_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/post_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/post_repository.dart';
import 'domain/repositories/friend_repository.dart';
import 'domain/usecases/auth/login_usecase.dart';
import 'domain/usecases/friend/send_friend_request_usecase.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/post/post_bloc.dart';
import 'presentation/blocs/friend/friend_bloc.dart';
import 'presentation/blocs/notification/notification_bloc.dart';
import 'presentation/blocs/search/search_bloc.dart';
import 'presentation/blocs/chat/chat_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton<HiveLocalDatasource>(() => HiveLocalDatasource());
  sl.registerLazySingleton<FakeRemoteDatasource>(
      () => FakeRemoteDatasource(sl()));

  sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: sl(), local: sl()));
  sl.registerLazySingleton<PostRepository>(
      () => PostRepositoryImpl(remote: sl(), local: sl()));
  sl.registerLazySingleton<FriendRepository>(
      () => FriendRepositoryImpl(remote: sl(), local: sl()));

  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => SendFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => AcceptFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => GetFriendRequestsUseCase(sl()));
  sl.registerLazySingleton(() => GetFriendsUseCase(sl()));
  sl.registerLazySingleton(() => GetSuggestionsUseCase(sl()));

  sl.registerLazySingleton(() => AuthBloc(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      local: sl()));
  sl.registerFactory(() => PostBloc(repository: sl()));
  sl.registerFactory(() => FriendBloc(
        sendRequestUseCase: sl(),
        acceptRequestUseCase: sl(),
        getFriendRequestsUseCase: sl(),
        getFriendsUseCase: sl(),
        getSuggestionsUseCase: sl(),
      ));
  sl.registerFactory(() => NotificationBloc(local: sl()));
  sl.registerFactory(() => SearchBloc(repository: sl()));
  sl.registerFactory(() => ChatBloc(localDatasource: sl()));
}
