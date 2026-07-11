import 'dart:async';
import 'dart:convert';
import 'package:chattify/services/api_client.dart';
import 'package:chattify/services/local_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _connected;

  Future<void> connect(int chatId) async {
    await close();
    final token = await LocalStore.getString('token');
    if (token == null || token.isEmpty) throw ApiException('Please login again');
    final base = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final uri = base.replace(scheme: wsScheme, path: '/ws/$chatId', queryParameters: {'token': token});
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    _connected = true;
    _subscription = _channel!.stream.listen((raw) {
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is Map<String, dynamic>) _events.add(decoded);
      } catch (_) {}
    }, onError: (Object error) {
      _connected = false;
      _events.add({'type': 'socket_error', 'error': error.toString()});
    }, onDone: () {
      _connected = false;
      _events.add({'type': 'socket_closed'});
    });
  }

  void sendText({required String text, int? replyToMessageId}) {
    _send({'type': 'message', 'message_type': 'text', 'message_text': text, if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId});
  }

  void sendGif({required String mediaUrl, String previewUrl = '', int? replyToMessageId}) {
    _send({'type': 'message', 'message_type': 'gif', 'message_text': '', 'media_url': mediaUrl, 'preview_url': previewUrl, if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId});
  }

  void sendTyping() => _send({'type': 'typing'});
  void sendDelivered(int messageId) => _send({'type': 'delivered', 'message_id': messageId});
  void sendRead(int messageId) => _send({'type': 'read_receipt', 'message_id': messageId});

  void _send(Map<String, dynamic> data) {
    if (!_connected || _channel == null) throw ApiException('Realtime connection is not ready');
    _channel!.sink.add(jsonEncode(data));
  }

  Future<void> close() async {
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}
