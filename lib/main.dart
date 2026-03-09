import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/datasources/local/hive_local_datasource.dart';
import 'injection_container.dart' as di;
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/post/post_bloc.dart';
import 'presentation/blocs/friend/friend_bloc.dart';
import 'presentation/blocs/notification/notification_bloc.dart';
import 'presentation/blocs/search/search_bloc.dart';
import 'presentation/blocs/chat/chat_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://qzxmrdfuhrsmtdaalsvl.supabase.co',
    anonKey: 'sb_publishable_gLovle81HAeXHFQVG3bV1Q_eEhIWuzT',
  );

  await Hive.initFlutter();
  await HiveLocalDatasource.init();
  await di.init();
  timeago.setLocaleMessages('vi', timeago.ViMessages());
  runApp(const StudyHubApp());
}

class StudyHubApp extends StatelessWidget {
  const StudyHubApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()..add(CheckAuthEvent())),
        BlocProvider(create: (_) => di.sl<PostBloc>()),
        BlocProvider(create: (_) => di.sl<FriendBloc>()),
        BlocProvider(create: (_) => di.sl<NotificationBloc>()),
        BlocProvider(create: (_) => di.sl<SearchBloc>()),
        BlocProvider(create: (_) => di.sl<ChatBloc>()),
      ],
      child: Builder(builder: (context) {
        final authBloc = context.read<AuthBloc>();
        return MaterialApp.router(
          title: 'StudyHub',
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.buildRouter(authBloc),
          debugShowCheckedModeBanner: false,
        );
      }),
    );
  }
}
