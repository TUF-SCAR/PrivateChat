class UiMessage {
  final int id;
  final int? senderId;
  final String text;
  final String senderName;
  final bool isMe;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final int readCount;
  final DateTime createdAt;
  final UiMessage? replyTo;

  UiMessage({
    required this.id,
    this.senderId,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.isRead,
    required this.isEdited,
    required this.isDeleted,
    this.readCount = 0,
    required this.createdAt,
    this.replyTo,
  });

  factory UiMessage.fromJson(Map<String, dynamic> json, {required int currentUserId}) {
    final senderId = _asNullableInt(json['sender_id']);
    final reply = json['reply_to'];
    return UiMessage(
      id: _asInt(json['message_id']),
      senderId: senderId,
      text: json['message_text']?.toString() ?? '',
      senderName: senderId == currentUserId ? 'You' : (json['sender_username']?.toString() ?? 'Unknown'),
      isMe: senderId == currentUserId,
      isRead: _asInt(json['read_count']) > 0,
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      readCount: _asInt(json['read_count']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      replyTo: reply is Map<String, dynamic>
          ? UiMessage(
              id: _asInt(reply['message_id']),
              senderId: _asNullableInt(reply['sender_id']),
              text: reply['message_text']?.toString() ?? '',
              senderName: _asNullableInt(reply['sender_id']) == currentUserId ? 'You' : (reply['sender_username']?.toString() ?? 'Unknown'),
              isMe: _asNullableInt(reply['sender_id']) == currentUserId,
              isRead: false,
              isEdited: false,
              isDeleted: false,
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
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      readCount: _asInt(json['read_count']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      replyTo: reply is Map ? UiMessage.fromCacheJson(Map<String, dynamic>.from(reply)) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'text': text,
      'sender_name': senderName,
      'is_me': isMe,
      'is_read': isRead,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'read_count': readCount,
      'created_at': createdAt.toIso8601String(),
      'reply_to': replyTo?.toJson(),
    };
  }

  UiMessage copyWith({
    String? text,
    bool? isRead,
    bool? isEdited,
    bool? isDeleted,
    int? readCount,
    UiMessage? replyTo,
  }) {
    return UiMessage(
      id: id,
      senderId: senderId,
      text: text ?? this.text,
      senderName: senderName,
      isMe: isMe,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      readCount: readCount ?? this.readCount,
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
