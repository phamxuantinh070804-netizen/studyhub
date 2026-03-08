import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/auth/forgot_password_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/home/main_shell.dart';
import '../../presentation/pages/friends/friends_page.dart';
import '../../presentation/pages/notifications/notifications_page.dart';
import '../../presentation/pages/profile/profile_page.dart';
import '../../presentation/pages/post/create_post_page.dart';
import '../../presentation/pages/post/post_detail_page.dart';
import '../../presentation/pages/search/search_page.dart';
import '../../presentation/pages/chat/chat_page.dart';
import '../../presentation/pages/chat/chat_list_page.dart';
import '../../presentation/pages/reels/reels_page.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter buildRouter(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/login',
      refreshListenable: _AuthNotifier(authBloc),
      redirect: (context, state) {
        final isLoggedIn = authBloc.state is AuthAuthenticated;
        final loc = state.matchedLocation;
        final isAuth =
            loc == '/login' || loc == '/register' || loc == '/forgot';
        if (!isLoggedIn && !isAuth) return '/login';
        if (isLoggedIn && isAuth) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
        GoRoute(
            path: '/forgot', builder: (_, __) => const ForgotPasswordPage()),
        ShellRoute(
          navigatorKey: _shellKey,
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
            GoRoute(path: '/reels', builder: (_, __) => const ReelsPage()),
            GoRoute(path: '/friends', builder: (_, __) => const FriendsPage()),
            GoRoute(
                path: '/notifications',
                builder: (_, __) => const NotificationsPage()),
            GoRoute(
                path: '/profile/:userId',
                builder: (_, s) =>
                    ProfilePage(userId: s.pathParameters['userId']!)),
            GoRoute(
                path: '/post/:postId',
                builder: (_, s) =>
                    PostDetailPage(postId: s.pathParameters['postId']!)),
          ],
        ),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: '/create-post',
            builder: (_, __) => const CreatePostPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: '/search',
            builder: (_, __) => const SearchPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: '/chat/:userId',
            builder: (_, s) =>
                ChatPage(otherUserId: s.pathParameters['userId']!)),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: '/chat',
            builder: (_, __) => const ChatListPage()),
      ],
    );
  }
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}
