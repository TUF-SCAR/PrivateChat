class UiChat {
  final int chatId;
  final String title;
  final String subtitle;
  final String time;
  final int unreadCount;
  final bool isGroup;
  final bool isOnline;
  final bool lastMessageIsMe;
  final bool lastMessageDelivered;
  final bool lastMessageRead;
  final int? otherUserId;
  final String? myRole;
  final DateTime? lastMessageDate;

  UiChat({
    required this.chatId,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.isOnline,
    this.lastMessageIsMe = false,
    this.lastMessageDelivered = true,
    this.lastMessageRead = false,
    this.otherUserId,
    this.myRole,
    this.lastMessageDate,
  });

  factory UiChat.fromPrivateJson(Map<String, dynamic> json) {
    final lastMessage = _cleanPreview(json['last_message']?.toString());
    final date = _parseDate(json['last_message_time']);
    return UiChat(
      chatId: json['chat_id'] as int,
      title: json['other_username']?.toString() ?? 'Unknown user',
      subtitle: lastMessage,
      time: _formatTime(date),
      unreadCount: _asInt(json['unread_count']),
      isGroup: false,
      isOnline: false,
      otherUserId: _asNullableInt(json['other_user_id']),
      myRole: 'member',
      lastMessageDate: date,
      lastMessageIsMe: json['last_message_is_me'] == true,
      lastMessageDelivered: json['last_message_delivered'] != false,
      lastMessageRead: json['last_message_read'] == true,
    );
  }

  factory UiChat.fromGroupJson(Map<String, dynamic> json) {
    final lastMessage = _cleanPreview(json['last_message']?.toString());
    final date = _parseDate(json['last_message_time']);
    return UiChat(
      chatId: json['chat_id'] as int,
      title: json['group_name']?.toString() ?? 'Unnamed group',
      subtitle: lastMessage,
      time: _formatTime(date),
      unreadCount: _asInt(json['unread_count']),
      isGroup: true,
      isOnline: false,
      otherUserId: null,
      myRole: json['my_role']?.toString(),
      lastMessageDate: date,
      lastMessageIsMe: json['last_message_is_me'] == true,
      lastMessageDelivered: json['last_message_delivered'] != false,
      lastMessageRead: json['last_message_read'] == true,
    );
  }

  factory UiChat.fromOpenChatJson(Map<String, dynamic> json) {
    final isGroup = json['is_group'] == true;
    return UiChat(
      chatId: json['chat_id'] as int,
      title: isGroup ? (json['chat_name']?.toString() ?? 'Unnamed group') : (json['other_username']?.toString() ?? 'Unknown user'),
      subtitle: isGroup ? 'Group chat' : 'Private chat',
      time: '',
      unreadCount: 0,
      isGroup: isGroup,
      isOnline: false,
      otherUserId: _asNullableInt(json['other_user_id']),
      myRole: json['my_role']?.toString(),
    );
  }


  factory UiChat.fromCacheJson(Map<String, dynamic> json) {
    final date = _parseDate(json['last_message_date']);
    return UiChat(
      chatId: _asInt(json['chat_id']),
      title: json['title']?.toString() ?? 'Unknown chat',
      subtitle: json['subtitle']?.toString() ?? 'No messages yet',
      time: json['time']?.toString() ?? _formatTime(date),
      unreadCount: _asInt(json['unread_count']),
      isGroup: json['is_group'] == true,
      isOnline: json['is_online'] == true,
      lastMessageIsMe: json['last_message_is_me'] == true,
      lastMessageDelivered: json['last_message_delivered'] != false,
      lastMessageRead: json['last_message_read'] == true,
      otherUserId: _asNullableInt(json['other_user_id']),
      myRole: json['my_role']?.toString(),
      lastMessageDate: date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'title': title,
      'subtitle': subtitle,
      'time': time,
      'unread_count': unreadCount,
      'is_group': isGroup,
      'is_online': isOnline,
      'last_message_is_me': lastMessageIsMe,
      'last_message_delivered': lastMessageDelivered,
      'last_message_read': lastMessageRead,
      'other_user_id': otherUserId,
      'my_role': myRole,
      'last_message_date': lastMessageDate?.toIso8601String(),
    };
  }

  String get initials {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
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

  static String _cleanPreview(String? text) {
    if (text == null || text.trim().isEmpty || text == 'null') return 'No messages yet';
    final trimmed = text.trim();
    if (trimmed.toUpperCase().startsWith('[GIF:')) return 'gif';
    return trimmed;
  }

  static String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}
