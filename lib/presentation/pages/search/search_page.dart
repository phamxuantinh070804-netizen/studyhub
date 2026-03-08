import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/search/search_bloc.dart';
import '../../blocs/friend/friend_bloc.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/post_entity.dart';
import 'package:timeago/timeago.dart' as timeago;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late TabController _tab;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() => _query = q);
    final auth = context.read<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.id : '';
    if (q.trim().isEmpty) {
      context.read<SearchBloc>().add(ClearSearchEvent());
      return;
    }
    context.read<SearchBloc>().add(SearchQueryEvent(query: q, userId: uid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        titleSpacing: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
              color: AppTheme.bgGrey, borderRadius: BorderRadius.circular(20)),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm trên StudyHub',
              hintStyle:
                  const TextStyle(color: AppTheme.textGrey, fontSize: 15),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textGrey, size: 20),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppTheme.textGrey),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _search,
          ),
        ),
        bottom: _query.isNotEmpty
            ? TabBar(
                controller: _tab,
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: AppTheme.textGrey,
                indicatorColor: AppTheme.primaryBlue,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Người'),
                  Tab(text: 'Bài viết'),
                ],
              )
            : null,
      ),
      body: BlocBuilder<SearchBloc, SearchState>(builder: (context, state) {
        if (state is SearchInitial) return _buildRecents();
        if (state is SearchLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue));
        }
        if (state is SearchLoaded) {
          if (_query.isEmpty) return _buildRecents();
          if (state.users.isEmpty && state.posts.isEmpty) {
            return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Không tìm thấy kết quả',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
                ]));
          }
          return TabBarView(controller: _tab, children: [
            _buildAll(context, state),
            _buildPeople(context, state.users),
            _buildPosts(state.posts),
          ]);
        }
        return const SizedBox();
      }),
    );
  }

  Widget _buildRecents() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Tìm kiếm gần đây',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        ...['bạn bè', 'bài viết hay', 'học lập trình'].map((q) => ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: AppTheme.bgGrey, shape: BoxShape.circle),
                  child: const Icon(Icons.history, color: AppTheme.textGrey)),
              title: Text(q),
              trailing: const Icon(Icons.north_west,
                  color: AppTheme.textGrey, size: 16),
              onTap: () {
                _ctrl.text = q;
                _search(q);
              },
            )),
      ]);

  Widget _buildAll(BuildContext context, SearchLoaded state) =>
      ListView(children: [
        if (state.users.isNotEmpty) ...[
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Mọi người',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ...state.users.take(3).map((u) => _UserTile(user: u)),
          if (state.users.length > 3)
            TextButton(
                onPressed: () => _tab.animateTo(1),
                child: Text('Xem tất cả ${state.users.length} người',
                    style: const TextStyle(color: AppTheme.primaryBlue))),
        ],
        if (state.posts.isNotEmpty) ...[
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Bài viết',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ...state.posts.take(3).map((p) => _PostTile(post: p)),
        ],
      ]);

  Widget _buildPeople(BuildContext context, List<UserEntity> users) {
    if (users.isEmpty) {
      return const Center(child: Text('Không tìm thấy người dùng'));
    }
    return ListView(children: users.map((u) => _UserTile(user: u)).toList());
  }

  Widget _buildPosts(List<PostEntity> posts) {
    if (posts.isEmpty) {
      return const Center(child: Text('Không tìm thấy bài viết'));
    }
    return ListView(children: posts.map((p) => _PostTile(post: p)).toList());
  }
}

class _UserTile extends StatefulWidget {
  final UserEntity user;
  const _UserTile({required this.user});
  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.id : '';
    final isMe = uid == widget.user.id;
    final isFriend =
        (auth is AuthAuthenticated) && auth.user.isFriendWith(widget.user.id);
    final hasSent = (auth is AuthAuthenticated) &&
        auth.user.hasSentRequestTo(widget.user.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/profile/${widget.user.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              AvatarWidget(
                  name: widget.user.name,
                  imageUrl: widget.user.avatarUrl,
                  radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${widget.user.friendIds.length} bạn bè',
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 13)),
                  ],
                ),
              ),
              if (!isMe)
                isFriend
                    ? OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/${widget.user.id}'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(100, 36),
                            foregroundColor: AppTheme.textDark,
                            side:
                                const BorderSide(color: AppTheme.borderColor)),
                        child: const Text('Bạn bè'))
                    : hasSent
                        ? OutlinedButton(
                            onPressed: () =>
                                context.push('/profile/${widget.user.id}'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(100, 36)),
                            child: const Text('Đã gửi'))
                        : ElevatedButton.icon(
                            onPressed: () {
                              context.read<FriendBloc>().add(
                                  SendFriendRequestEvent(
                                      fromId: uid, toId: widget.user.id));
                            },
                            icon: const Icon(Icons.person_add,
                                size: 16, color: Colors.white),
                            label: const Text('Thêm bạn',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              minimumSize: const Size(100, 36),
                            ),
                          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final PostEntity post;
  const _PostTile({required this.post});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: AvatarWidget(
            name: post.authorName, imageUrl: post.authorAvatar, radius: 20),
        title: Text(post.authorName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.content != null)
            Text(post.content!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          Text(timeago.format(post.createdAt, locale: 'vi'),
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ]),
        onTap: () => context.push('/post/${post.id}'),
      );
}
