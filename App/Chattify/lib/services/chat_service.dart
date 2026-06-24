import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/services/api_client.dart';

class ChatService {
  ChatService._();

  static Future<List<UiChat>> getAllChats() async {
    final privateData = await ApiClient.get('/chats');
    final groupData = await ApiClient.get('/groups');

    final privateRows = privateData['chats'] is List ? privateData['chats'] as List : [];
    final groupRows = groupData['groups'] is List ? groupData['groups'] as List : [];

    final chats = <UiChat>[
      ...privateRows.whereType<Map<String, dynamic>>().map(UiChat.fromPrivateJson),
      ...groupRows.whereType<Map<String, dynamic>>().map(UiChat.fromGroupJson),
    ];

    chats.sort((a, b) {
      final at = a.lastMessageDate;
      final bt = b.lastMessageDate;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return chats;
  }

  static Future<UiChat> openChat(int chatId) async {
    final data = await ApiClient.get('/chats/$chatId');
    final chat = data['chat'];
    if (chat is! Map<String, dynamic>) throw ApiException('Invalid chat response');
    return UiChat.fromOpenChatJson(chat);
  }

  static Future<int> createPrivateChat(int otherUserId) async {
    final data = await ApiClient.post('/chats', {'other_user_id': otherUserId});
    final id = data['chat_id'];
    if (id is! int) throw ApiException('Invalid create chat response');
    return id;
  }

  static Future<void> deletePrivateChat(int chatId) async {
    await ApiClient.delete('/chats/$chatId');
  }
}
