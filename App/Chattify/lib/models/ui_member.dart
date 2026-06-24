class UiMember {
  final int userId;
  final String username;
  final String role;
  final bool isOnline;

  UiMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.isOnline,
  });

  factory UiMember.fromJson(Map<String, dynamic> json) {
    return UiMember(
      userId: json['user_id'] as int,
      username: json['username']?.toString() ?? 'Unknown',
      role: json['role']?.toString() ?? 'member',
      isOnline: false,
    );
  }

  String get initials {
    final words = username.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
