class UiMessage {
  final int id;
  final int? senderId;
  final String text;
  final String senderName;
  final bool isMe;
  final bool isRead;
  final bool isDelivered;
  final bool isEdited;
  final bool isDeleted;
  final int readCount;
  final int deliveryCount;
  final String messageType;
  final String mediaUrl;
  final String previewUrl;
  final DateTime createdAt;
  final UiMessage? replyTo;

  UiMessage({
    required this.id,
    this.senderId,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.isRead,
    this.isDelivered = false,
    required this.isEdited,
    required this.isDeleted,
    this.readCount = 0,
    this.deliveryCount = 0,
    this.messageType = 'text',
    this.mediaUrl = '',
    this.previewUrl = '',
    required this.createdAt,
    this.replyTo,
  });

  bool get isGif => messageType == 'gif';

  factory UiMessage.fromJson(Map<String, dynamic> json, {required int currentUserId}) {
    final senderId = _asNullableInt(json['sender_id']);
    final reply = json['reply_to'];
    final readCount = _asInt(json['read_count']);
    final deliveryCount = _asInt(json['delivery_count']);
    return UiMessage(
      id: _asInt(json['message_id']),
      senderId: senderId,
      text: json['message_text']?.toString() ?? '',
      senderName: senderId == currentUserId ? 'You' : (json['sender_username']?.toString() ?? 'Unknown'),
      isMe: senderId == currentUserId,
      isRead: readCount > 0,
      isDelivered: deliveryCount > 0,
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      readCount: readCount,
      deliveryCount: deliveryCount,
      messageType: json['message_type']?.toString() ?? 'text',
      mediaUrl: json['media_url']?.toString() ?? '',
      previewUrl: json['preview_url']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      replyTo: reply is Map<String, dynamic>
          ? UiMessage(
              id: _asInt(reply['message_id']),
              senderId: _asNullableInt(reply['sender_id']),
              text: reply['message_text']?.toString() ?? '',
              senderName: _asNullableInt(reply['sender_id']) == currentUserId ? 'You' : (reply['sender_username']?.toString() ?? 'Unknown'),
              isMe: _asNullableInt(reply['sender_id']) == currentUserId,
              isRead: false,
              isDelivered: false,
              isEdited: false,
              isDeleted: false,
              messageType: reply['message_type']?.toString() ?? 'text',
              mediaUrl: reply['media_url']?.toString() ?? '',
              previewUrl: reply['preview_url']?.toString() ?? '',
              createdAt: DateTime.now(),
            )
          : null,
    );
  }

  factory UiMessage.fromCacheJson(Map<String, dynamic> json) {
    final reply = json['reply_to'];
    return UiMessage(
      id: _asInt(json['id']),
      senderId: _asNullableInt(json['sender_id']),
      text: json['text']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Unknown',
      isMe: json['is_me'] == true,
      isRead: json['is_read'] == true,
      isDelivered: json['is_delivered'] == true,
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      readCount: _asInt(json['read_count']),
      deliveryCount: _asInt(json['delivery_count']),
      messageType: json['message_type']?.toString() ?? 'text',
      mediaUrl: json['media_url']?.toString() ?? '',
      previewUrl: json['preview_url']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      replyTo: reply is Map ? UiMessage.fromCacheJson(Map<String, dynamic>.from(reply)) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'text': text,
        'sender_name': senderName,
        'is_me': isMe,
        'is_read': isRead,
        'is_delivered': isDelivered,
        'is_edited': isEdited,
        'is_deleted': isDeleted,
        'read_count': readCount,
        'delivery_count': deliveryCount,
        'message_type': messageType,
        'media_url': mediaUrl,
        'preview_url': previewUrl,
        'created_at': createdAt.toIso8601String(),
        'reply_to': replyTo?.toJson(),
      };

  UiMessage copyWith({
    String? text,
    bool? isRead,
    bool? isDelivered,
    bool? isEdited,
    bool? isDeleted,
    int? readCount,
    int? deliveryCount,
    UiMessage? replyTo,
  }) {
    return UiMessage(
      id: id,
      senderId: senderId,
      text: text ?? this.text,
      senderName: senderName,
      isMe: isMe,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      readCount: readCount ?? this.readCount,
      deliveryCount: deliveryCount ?? this.deliveryCount,
      messageType: messageType,
      mediaUrl: mediaUrl,
      previewUrl: previewUrl,
      createdAt: createdAt,
      replyTo: replyTo ?? this.replyTo,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty || raw == 'None' || raw == 'null') return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
}
