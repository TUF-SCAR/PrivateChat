import 'package:chattify/services/api_client.dart';
import 'package:chattify/services/local_store.dart';

class CurrentUser {
  final int id;
  final String username;

  CurrentUser({required this.id, required this.username});
}

class AuthService {
  AuthService._();

  static Future<void> register({required String username, required String email, required String password}) async {
    await ApiClient.post('/register', {
      'username': username,
      'email': email,
      'password': password,
    }, auth: false);
  }

  static Future<CurrentUser> login({required String emailOrUsername, required String password}) async {
    final data = await ApiClient.post('/login', {
      'email_or_username': emailOrUsername,
      'password': password,
    }, auth: false);

    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) throw ApiException('Login response did not include token');
    await LocalStore.setString('token', token);

    final me = await getMe();
    await LocalStore.setInt('user_id', me.id);
    await LocalStore.setString('username', me.username);
    return me;
  }

  static Future<CurrentUser> getMe() async {
    final data = await ApiClient.get('/me');
    final id = data['id'];
    final username = data['username']?.toString();
    if (id is! int || username == null) throw ApiException('Invalid /me response');
    await LocalStore.setInt('user_id', id);
    await LocalStore.setString('username', username);
    return CurrentUser(id: id, username: username);
  }

  static Future<int?> currentUserId() => LocalStore.getInt('user_id');
  static Future<String?> currentUsername() => LocalStore.getString('username');
  static Future<String?> token() => LocalStore.getString('token');

  static Future<void> logout() async {
    await LocalStore.clearAuth();
  }
}
