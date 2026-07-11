import 'package:chattify/models/ui_message.dart';
import 'package:chattify/services/api_client.dart';

class MessageService {
  MessageService._();

  static Future<List<UiMessage>> getMessages({required int chatId, required int currentUserId, int limit = 50, int offset = 0}) async {
    final data = await ApiClient.get('/messages/$chatId', query: {'limit': '$limit', 'offset': '$offset'});
    final rows = data['messages'];
    if (rows is! List) return [];
    return rows.whereType<Map<String, dynamic>>().map((row) => UiMessage.fromJson(row, currentUserId: currentUserId)).toList().reversed.toList();
  }

  static Future<int> sendText({required int chatId, required String text, int? replyToMessageId}) async {
    final body = <String, dynamic>{'chat_id': chatId, 'message_text': text, 'message_type': 'text'};
    if (replyToMessageId != null) body['reply_to_message_id'] = replyToMessageId;
    final data = await ApiClient.post('/messages', body);
    final id = data['message_id'];
    if (id is! int) throw ApiException('Invalid send message response');
    return id;
  }

  static Future<int> sendGif({required int chatId, required String mediaUrl, String previewUrl = '', int? replyToMessageId}) async {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'message_text': '',
      'message_type': 'gif',
      'media_url': mediaUrl,
      'preview_url': previewUrl,
    };
    if (replyToMessageId != null) body['reply_to_message_id'] = replyToMessageId;
    final data = await ApiClient.post('/messages', body);
    final id = data['message_id'];
    if (id is! int) throw ApiException('Invalid GIF response');
    return id;
  }

  static Future<void> editMessage({required int messageId, required String text}) async => ApiClient.patch('/messages/$messageId', {'message_text': text});
  static Future<void> deleteMessage(int messageId) async => ApiClient.delete('/messages/$messageId');
  static Future<void> markChatAsRead(int chatId) async => ApiClient.post('/chats/$chatId/read', {});
  static Future<void> markDelivered(int messageId) async => ApiClient.post('/messages/$messageId/delivered', {});
  static Future<void> markRead(int messageId) async => ApiClient.post('/messages/$messageId/read', {});

  static Future<List<Map<String, dynamic>>> getReads(int messageId) async {
    final data = await ApiClient.get('/messages/$messageId/reads');
    final rows = data['read_by'];
    if (rows is! List) return [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }
}
