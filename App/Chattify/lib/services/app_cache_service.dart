import 'dart:convert';
import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/models/ui_message.dart';
import 'package:chattify/services/local_store.dart';

class AppCacheService {
  AppCacheService._();

  static const String _chatListKey = 'cache_chat_list_v1';

  static String _messagesKey(int chatId) => 'cache_messages_chat_${chatId}_v1';

  static Future<void> saveChats(List<UiChat> chats) async {
    final data = chats.map((chat) => chat.toJson()).toList();
    await LocalStore.setString(_chatListKey, jsonEncode(data));
  }

  static Future<List<UiChat>> loadChats() async {
    final raw = await LocalStore.getString(_chatListKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => UiChat.fromCacheJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMessages({required int chatId, required List<UiMessage> messages}) async {
    final data = messages.map((message) => message.toJson()).toList();
    await LocalStore.setString(_messagesKey(chatId), jsonEncode(data));
  }

  static Future<List<UiMessage>> loadMessages(int chatId) async {
    final raw = await LocalStore.getString(_messagesKey(chatId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => UiMessage.fromCacheJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
