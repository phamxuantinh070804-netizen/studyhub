import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/friend/friend_bloc.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../widgets/common/avatar_widget.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Timer? _refreshTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location.startsWith('/reels')) return 1;
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/menu')) {
      return 4;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        context
            .read<NotificationBloc>()
            .add(LoadNotificationsEvent(auth.user.id));
        context.read<FriendBloc>().add(LoadFriendRequestsEvent(auth.user.id));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTap(int i) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    if (i == 0) context.go('/');
    if (i == 1) context.go('/reels');
    if (i == 2) context.go('/friends');
    if (i == 3) context.go('/notifications');
    if (i == 4) {
      context.go('/profile/${auth.user.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _calculateSelectedIndex(context);
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildMenuDrawer(context),
      body: widget.child,
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFCCD0D5), width: 0.5)),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomItem(
                icon: Icons.home,
                activeIcon: Icons.home,
                label: 'Trang chủ',
                index: 0,
                current: index,
                onTap: _onTap),
            _BottomItem(
                icon: Icons.ondemand_video,
                activeIcon: Icons.ondemand_video,
                label: 'Reels',
                index: 1,
                current: index,
                onTap: _onTap),
            _BottomItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Bạn bè',
                index: 2,
                current: index,
                onTap: _onTap),
            _BottomItem(
              icon: Icons.notifications_none,
              activeIcon: Icons.notifications,
              label: 'Thông báo',
              index: 3,
              current: index,
              onTap: _onTap,
              badgeCount: BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, ns) {
                  final count = ns is NotifLoaded ? ns.unreadCount : 0;
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  );
                },
              ),
            ),
            _BottomItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle,
              label: 'Cá nhân',
              index: 4,
              current: index,
              onTap: _onTap,
              avatar: user != null
                  ? AvatarWidget(
                      name: user.name, imageUrl: user.avatarUrl, radius: 11)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDrawer(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: AvatarWidget(
                  name: user?.name ?? '',
                  imageUrl: user?.avatarUrl,
                  radius: 20),
              title: Text(user?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_drop_down_circle_outlined),
              onTap: () {
                context.pop();
                context.push('/profile/${user?.id}');
              },
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _DrawerItem(
                      icon: Icons.people,
                      label: 'Bạn bè',
                      color: Colors.blue,
                      onTap: () {
                        context.pop();
                        context.go('/friends');
                      }),
                  _DrawerItem(
                      icon: Icons.ondemand_video,
                      label: 'Thước phim',
                      color: Colors.red,
                      onTap: () {
                        context.pop();
                        context.go('/reels');
                      }),
                  const Divider(),
                  const _DrawerItem(
                      icon: Icons.help, label: 'Trợ giúp và hỗ trợ'),
                  const _DrawerItem(
                      icon: Icons.settings, label: 'Cài đặt & quyền riêng tư'),
                  _DrawerItem(
                      icon: Icons.logout,
                      label: 'Đăng xuất',
                      onTap: () {
                        context.read<AuthBloc>().add(LogoutEvent());
                        context.go('/login');
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  final Widget? badgeCount;
  final Widget? avatar;

  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badgeCount,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (avatar != null)
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1877F2)
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: avatar,
                )
              else
                Icon(isSelected ? activeIcon : icon,
                    color: isSelected
                        ? const Color(0xFF1877F2)
                        : const Color(0xFF65676B),
                    size: 28),
              if (badgeCount != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: badgeCount!,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? const Color(0xFF1877F2)
                      : const Color(0xFF65676B))),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _DrawerItem(
      {required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
