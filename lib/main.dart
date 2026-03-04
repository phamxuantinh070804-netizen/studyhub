import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/posts/data/repositories/post_repository_impl.dart';
import 'features/posts/presentation/bloc/post_bloc.dart';
import 'features/posts/presentation/pages/post_page.dart';

void main() {
  final repository = PostRepositoryImpl();

  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final PostRepositoryImpl repository;

  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (_) => PostBloc(repository),
        child: const PostPage(),
      ),
    );
  }
}