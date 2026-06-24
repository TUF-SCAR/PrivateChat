import 'package:chattify/models/ui_member.dart';
import 'package:chattify/services/api_client.dart';

class GroupService {
  GroupService._();

  static Future<int> createGroup({required String name, required List<int> memberIds}) async {
    final data = await ApiClient.post('/groups', {'name': name, 'member_ids': memberIds});
    final id = data['chat_id'];
    if (id is! int) throw ApiException('Invalid create group response');
    return id;
  }

  static Future<List<UiMember>> getMembers(int chatId) async {
    final data = await ApiClient.get('/groups/$chatId/members');
    final rows = data['members'];
    if (rows is! List) return [];
    return rows.whereType<Map<String, dynamic>>().map(UiMember.fromJson).toList();
  }

  static Future<void> addMember({required int chatId, required int userId}) async {
    await ApiClient.post('/groups/$chatId/members', {'user_id': userId});
  }

  static Future<void> removeMember({required int chatId, required int userId}) async {
    await ApiClient.delete('/groups/$chatId/members/$userId');
  }

  static Future<void> changeRole({required int chatId, required int userId, required String role}) async {
    await ApiClient.patch('/groups/$chatId/members/$userId/role', {'role': role});
  }

  static Future<void> renameGroup({required int chatId, required String name}) async {
    await ApiClient.patch('/groups/$chatId', {'name': name});
  }

  static Future<void> leaveGroup(int chatId) async {
    await ApiClient.delete('/groups/$chatId/leave');
  }

  static Future<void> deleteGroup(int chatId) async {
    await ApiClient.delete('/groups/$chatId');
  }
}
