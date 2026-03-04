import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';

abstract class PostLocalDataSource {
  Future<void> cachePosts(List<PostModel> posts);
  Future<List<PostModel>> getCachedPosts();
}

class PostLocalDataSourceImpl implements PostLocalDataSource {
  final SharedPreferences sharedPreferences;

  PostLocalDataSourceImpl(this.sharedPreferences);

  static const String CACHED_POSTS = "CACHED_POSTS";

  @override
  Future<void> cachePosts(List<PostModel> posts) async {
    final jsonList =
    posts.map((e) => json.encode(e.toJson())).toList();

    await sharedPreferences.setStringList(CACHED_POSTS, jsonList);
  }

  @override
  Future<List<PostModel>> getCachedPosts() async {
    final jsonList =
    sharedPreferences.getStringList(CACHED_POSTS);

    if (jsonList != null) {
      return jsonList
          .map((e) =>
          PostModel.fromJson(json.decode(e)))
          .toList();
    }
    return [];
  }
}