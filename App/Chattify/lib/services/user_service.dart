import 'package:chattify/services/api_client.dart';

class SearchUser {
  final int id;
  final String username;

  SearchUser({required this.id, required this.username});

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id'] as int,
      username: json['username'].toString(),
    );
  }
}

class UserService {
  UserService._();

  static Future<List<SearchUser>> searchUsers(String username) async {
    final q = username.trim();
    if (q.isEmpty) return [];
    final data = await ApiClient.get('/users/search', query: {'username': q});
    final users = data['users'];
    if (users is! List) return [];
    return users.whereType<Map<String, dynamic>>().map(SearchUser.fromJson).toList();
  }
}
