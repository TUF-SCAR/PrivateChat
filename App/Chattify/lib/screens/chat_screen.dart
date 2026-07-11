import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';
import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/services/message_service.dart';
import 'package:chattify/services/chat_socket_service.dart';
import 'package:chattify/services/local_store.dart';
import 'package:chattify/services/app_cache_service.dart';
import 'package:chattify/models/ui_message.dart';
import 'package:chattify/screens/chat_info_screen.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';
import 'package:chattify/widgets/chat_avatar.dart';
import 'package:chattify/widgets/chat_background.dart';
import 'package:chattify/widgets/message_bubble.dart';
import 'package:chattify/utils/emoji_search_index.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final UiChat chat;
  final VoidCallback? onArchive;

  const ChatScreen({super.key, required this.chat, this.onArchive});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final searchController = TextEditingController();
  final gifSearchController = TextEditingController();
  final scrollController = ScrollController();
  final emojiScrollController = ScrollController();
  final emojiSearchController = TextEditingController();
  final messageFocusNode = FocusNode();
  final List<GlobalKey> emojiCategoryKeys = List.generate(14, (_) => GlobalKey());

  UiMessage? replyTarget;
  int nextMessageId = 100;
  bool searchMode = false;
  bool showEmojiPanel = false;
  bool showGifKeyboard = false;
  int selectedEmojiCategory = 0;
  String searchText = '';
  String gifSearchText = '';
  String emojiSearchText = '';
  String selectedSkinTone = '';
  List<String> recentEmojis = [];
  bool recentLoaded = false;
  final Set<int> pinnedMessageIds = {11};

  List<UiMessage> messages = [];
  bool isLoadingMessages = true;
  String? messageError;
  int currentUserId = 0;
  final ChatSocketService socketService = ChatSocketService();
  StreamSubscription<Map<String, dynamic>>? socketSubscription;
  bool socketReady = false;
  bool peerOnline = false;
  String? typingUsername;
  Timer? typingTimer;
  DateTime lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);


  @override
  void initState() {
    super.initState();
    loadRecentEmojis();
    messageController.addListener(_handleTyping);
    loadMessages();
  }

  Future<void> loadRecentEmojis() async {
    final savedTone = await LocalStore.getString('emoji_skin_tone');
    final savedRecent = await LocalStore.getStringList('recent_emojis_v1');
    if (!mounted) return;
    setState(() {
      selectedSkinTone = savedTone ?? '';
      recentEmojis = savedRecent.isEmpty
          ? ['😂', '😭', '🔥', '💀', '❤️', '👍', '🥲', '😤', '👀', '✨', '🙏', '🗿']
          : savedRecent.take(36).toList();
      recentLoaded = true;
    });
  }

  Future<void> saveRecentEmojis() async {
    await LocalStore.setStringList('recent_emojis_v1', recentEmojis.take(36).toList());
  }


  Future<void> connectSocket() async {
    try {
      await socketService.connect(widget.chat.chatId);
      socketSubscription?.cancel();
      socketSubscription = socketService.events.listen(_handleSocketEvent);
      if (!mounted) return;
      setState(() => socketReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => socketReady = false);
    }
  }

  void _handleTyping() {
    if (!socketReady || messageController.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(lastTypingSent).inMilliseconds < 1200) return;
    lastTypingSent = now;
    try { socketService.sendTyping(); } catch (_) {}
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString();
    if (type == 'message') {
      final incoming = UiMessage.fromJson(event, currentUserId: currentUserId);
      setState(() {
        final index = messages.indexWhere((m) => m.id == incoming.id);
        if (index >= 0) {
          messages[index] = incoming;
        } else {
          messages.add(incoming);
          messages = sortMessagesOldestToNewest(messages);
        }
      });
      AppCacheService.saveMessages(chatId: widget.chat.chatId, messages: messages);
      if (!incoming.isMe) {
        try {
          socketService.sendDelivered(incoming.id);
          socketService.sendRead(incoming.id);
        } catch (_) {}
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBottom());
    } else if (type == 'delivered') {
      final id = int.tryParse(event['message_id'].toString());
      if (id != null) _updateReceipt(id, delivered: true);
    } else if (type == 'read_receipt') {
      final id = int.tryParse(event['message_id'].toString());
      if (id != null) _updateReceipt(id, delivered: true, read: true);
    } else if (type == 'online') {
      if (!widget.chat.isGroup && event['user_id'] != currentUserId) setState(() => peerOnline = true);
    } else if (type == 'offline') {
      if (!widget.chat.isGroup && event['user_id'] != currentUserId) setState(() => peerOnline = false);
    } else if (type == 'typing') {
      if (event['user_id'] == currentUserId) return;
      setState(() => typingUsername = event['username']?.toString());
      typingTimer?.cancel();
      typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => typingUsername = null);
      });
    } else if (type == 'socket_closed' || type == 'socket_error') {
      setState(() => socketReady = false);
    }
  }

  void _updateReceipt(int messageId, {bool delivered = false, bool read = false}) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final old = messages[index];
    setState(() {
      messages[index] = old.copyWith(
        isDelivered: delivered || old.isDelivered,
        isRead: read || old.isRead,
        deliveryCount: delivered ? (old.deliveryCount < 1 ? 1 : old.deliveryCount) : old.deliveryCount,
        readCount: read ? (old.readCount < 1 ? 1 : old.readCount) : old.readCount,
      );
    });
  }

  Future<void> loadMessages() async {
    setState(() {
      isLoadingMessages = messages.isEmpty;
      messageError = null;
    });

    final cached = await AppCacheService.loadMessages(widget.chat.chatId);
    if (mounted && cached.isNotEmpty && messages.isEmpty) {
      setState(() {
        messages = sortMessagesOldestToNewest(cached);
        isLoadingMessages = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBottom());
    }

    try {
      currentUserId = await AuthService.currentUserId() ?? (await AuthService.getMe()).id;
      if (!socketReady) await connectSocket();
      final loaded = await MessageService.getMessages(chatId: widget.chat.chatId, currentUserId: currentUserId);
      await MessageService.markChatAsRead(widget.chat.chatId);
      await AppCacheService.saveMessages(chatId: widget.chat.chatId, messages: loaded);
      if (!mounted) return;
      setState(() {
        messages = sortMessagesOldestToNewest(loaded);
        isLoadingMessages = false;
        messageError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        messageError = messages.isEmpty ? error.toString() : null;
        isLoadingMessages = false;
      });
    }
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void rememberEmoji(String emoji) {
    final clean = emoji.trim();
    if (clean.isEmpty) return;
    setState(() {
      recentEmojis.remove(clean);
      recentEmojis.insert(0, clean);
      if (recentEmojis.length > 36) recentEmojis = recentEmojis.take(36).toList();
    });
    saveRecentEmojis();
  }

  List<UiMessage> _buildFakeMessages() {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final old = now.subtract(Duration(days: 4));
    final older = now.subtract(Duration(days: 9));

    UiMessage msg(int id, String text, String sender, bool me, DateTime time, {UiMessage? reply}) {
      return UiMessage(id: id, text: text, senderName: sender, isMe: me, isRead: id.isEven, isEdited: false, isDeleted: false, createdAt: time, replyTo: reply);
    }

    final m1 = msg(1, 'Old message for testing date groups.', widget.chat.isGroup ? 'Tuf Zoro' : widget.chat.title, false, DateTime(older.year, older.month, older.day, 20, 8));
    final m2 = msg(2, 'This should appear under its own date header.', 'You', true, DateTime(older.year, older.month, older.day, 20, 11), reply: m1);
    final m3 = msg(3, 'Backend routes are mostly ready now.', widget.chat.isGroup ? 'PrivateChat Dev' : widget.chat.title, false, DateTime(old.year, old.month, old.day, 18, 10));
    final m4 = msg(4, 'Good. First we finish clean UI, then connect APIs.', 'You', true, DateTime(old.year, old.month, old.day, 18, 14), reply: m3);
    final m5 = msg(5, 'Add more fake messages for date grouping debug.', widget.chat.isGroup ? 'Tuf Zoro' : widget.chat.title, false, DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 20));
    final m6 = msg(6, 'Done. Today, yesterday, and date headers should be visible.', 'You', true, DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 26), reply: m5);
    final m7 = msg(7, 'Also test search inside messages.', widget.chat.isGroup ? 'App Team' : widget.chat.title, false, DateTime(yesterday.year, yesterday.month, yesterday.day, 11, 4));
    final m8 = msg(8, 'Search should highlight matching bubbles and hide non-matches.', 'You', true, DateTime(yesterday.year, yesterday.month, yesterday.day, 11, 8));
    final m9 = msg(9, 'Bro where are you?', widget.chat.isGroup ? 'Tuf Zoro' : widget.chat.title, false, now.subtract(Duration(hours: 3, minutes: 20)));
    final m10 = msg(10, 'I am fixing the theme/settings flow.', 'You', true, now.subtract(Duration(hours: 2, minutes: 48)));
    final m11 = msg(11, 'Swipe any message to reply. Long press for actions.', widget.chat.isGroup ? 'PrivateChat Dev' : widget.chat.title, false, now.subtract(Duration(hours: 1, minutes: 45)), reply: m10);
    final m12 = msg(12, 'Good. Remove unsupported buttons for now.', widget.chat.isGroup ? 'Tuf Zoro' : widget.chat.title, false, now.subtract(Duration(minutes: 40)));
    final m13 = msg(13, '3 dots now shows settings and pinned messages.', 'You', true, now.subtract(Duration(minutes: 16)));
    final m14 = msg(14, widget.chat.isGroup ? 'Later we connect members, roles, and admin actions.' : 'For private chats we can keep delete-for-me and archive.', widget.chat.isGroup ? 'App Team' : widget.chat.title, false, now.subtract(Duration(minutes: 5)));

    return [m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14];
  }

  List<UiMessage> get visibleMessages {
    final query = searchText.trim().toLowerCase();
    if (!searchMode || query.isEmpty) return messages;
    return messages.where((m) => m.text.toLowerCase().contains(query) || m.senderName.toLowerCase().contains(query) || (m.replyTo?.text.toLowerCase().contains(query) ?? false)).toList();
  }

  void jumpToBottom() {
    if (!scrollController.hasClients) return;
    // This ListView is reversed. In a reversed list, offset 0 is the visual bottom.
    // So we hard-force the chat to the newest/latest message with no animation.
    scrollController.jumpTo(scrollController.position.minScrollExtent);
  }

  List<UiMessage> sortMessagesOldestToNewest(List<UiMessage> input) {
    final copy = [...input];
    copy.sort((a, b) {
      final timeCompare = a.createdAt.compareTo(b.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final reply = replyTarget;
    messageController.clear();
    setState(() {
      replyTarget = null;
      showEmojiPanel = false;
      showGifKeyboard = false;
    });
    try {
      if (socketService.isConnected) {
        socketService.sendText(text: text, replyToMessageId: reply?.id);
      } else {
        await MessageService.sendText(chatId: widget.chat.chatId, text: text, replyToMessageId: reply?.id);
        await loadMessages();
      }
    } catch (error) {
      showSnack(error.toString());
    }
  }

  Future<void> sendGif(String label) async {
    final reply = replyTarget;
    setState(() {
      replyTarget = null;
      showGifKeyboard = false;
      showEmojiPanel = false;
    });
    try {
      final gif = _gifForLabel(label);
      if (socketService.isConnected) {
        socketService.sendGif(mediaUrl: gif.$1, previewUrl: gif.$2, replyToMessageId: reply?.id);
      } else {
        await MessageService.sendGif(chatId: widget.chat.chatId, mediaUrl: gif.$1, previewUrl: gif.$2, replyToMessageId: reply?.id);
        await loadMessages();
      }
    } catch (error) {
      showSnack(error.toString());
    }
  }

  (String, String) _gifForLabel(String label) {
    const gifs = <String, (String, String)>{
      'happy dance': ('https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200_s.gif'),
      'anime shock': ('https://media.giphy.com/media/GRk3GLfzduq1NtfGt5/giphy.gif', 'https://media.giphy.com/media/GRk3GLfzduq1NtfGt5/200_s.gif'),
      'typing fast': ('https://media.giphy.com/media/13GIgrGdslD9oQ/giphy.gif', 'https://media.giphy.com/media/13GIgrGdslD9oQ/200_s.gif'),
      'mission passed': ('https://media.giphy.com/media/a0h7sAqON67nO/giphy.gif', 'https://media.giphy.com/media/a0h7sAqON67nO/200_s.gif'),
      'bruh moment': ('https://media.giphy.com/media/ji6zzUZwNIuLS/giphy.gif', 'https://media.giphy.com/media/ji6zzUZwNIuLS/200_s.gif'),
      'demon mode': ('https://media.giphy.com/media/yr7n0u3qzO9nG/giphy.gif', 'https://media.giphy.com/media/yr7n0u3qzO9nG/200_s.gif'),
    };
    return gifs[label] ?? ('https://media.giphy.com/media/3o7aD2saalBwwftBIY/giphy.gif', 'https://media.giphy.com/media/3o7aD2saalBwwftBIY/200_s.gif');
  }

  void startReply(UiMessage message) {
    setState(() {
      replyTarget = message;
      showEmojiPanel = false;
      showGifKeyboard = false;
    });
    messageFocusNode.requestFocus();
  }

  String dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool shouldShowDateHeader(List<UiMessage> list, int index) {
    if (index == 0) return true;
    final current = list[index].createdAt;
    final previous = list[index - 1].createdAt;
    return current.year != previous.year || current.month != previous.month || current.day != previous.day;
  }

  Widget dateHeader(String label, PrivateChatTheme theme) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: theme.surface.withOpacity(0.92), borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.border)),
        child: Text(label, style: TextStyle(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    );
  }

  void showMessageActions(UiMessage message) {
    FocusManager.instance.primaryFocus?.unfocus();
    final isPinned = pinnedMessageIds.contains(message.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = appThemeController.themeForChat(widget.chat.chatId);
        return Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 26 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999))),
            SizedBox(height: 14),
            _actionTile(theme, icon: Icons.reply_rounded, title: 'Reply', onTap: () { Navigator.pop(context); startReply(message); }),
            _actionTile(theme, icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, title: isPinned ? 'Unpin message' : 'Pin message', onTap: () { Navigator.pop(context); setState(() { if (isPinned) pinnedMessageIds.remove(message.id); else pinnedMessageIds.add(message.id); }); }),
            if (message.isMe && !message.isDeleted && !message.isGif) _actionTile(theme, icon: Icons.edit_rounded, title: 'Edit message', onTap: () { Navigator.pop(context); startEdit(message); }),
            if (!message.isGif) _actionTile(theme, icon: Icons.copy_rounded, title: 'Copy text', onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: message.text)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message copied'))); }),
            if (message.isMe && !message.isDeleted) _actionTile(theme, icon: Icons.delete_outline_rounded, title: 'Delete message', isDanger: true, onTap: () async { Navigator.pop(context); try { await MessageService.deleteMessage(message.id); await loadMessages(); } catch (error) { showSnack(error.toString()); } }),
          ]),
        );
      },
    );
  }

  void startEdit(UiMessage message) {
    FocusManager.instance.primaryFocus?.unfocus();
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit message'),
        content: TextField(controller: editController, maxLines: null, autofocus: true, decoration: InputDecoration(hintText: 'Message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          FilledButton(onPressed: () async { final newText = editController.text.trim(); if (newText.isEmpty) return; Navigator.pop(context); try { await MessageService.editMessage(messageId: message.id, text: newText); await loadMessages(); } catch (error) { showSnack(error.toString()); } }, child: Text('Save')),
        ],
      ),
    );
  }

  Widget _actionTile(PrivateChatTheme theme, {required IconData icon, required String title, required VoidCallback onTap, bool isDanger = false}) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? AppColors.danger : theme.text),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: isDanger ? AppColors.danger : theme.text)),
      onTap: onTap,
    );
  }

  void showChatMenu(PrivateChatTheme theme) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 26 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999))),
          SizedBox(height: 14),
          _actionTile(theme, icon: Icons.settings_rounded, title: 'Settings', onTap: () { Navigator.pop(context); openSettings(); }),
          _actionTile(theme, icon: Icons.push_pin_rounded, title: 'Pinned messages', onTap: () { Navigator.pop(context); showPinnedMessages(theme); }),
        ]),
      ),
    );
  }

  void openSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatInfoScreen(chat: widget.chat, onArchive: widget.onArchive)));
  }

  void showPinnedMessages(PrivateChatTheme theme) {
    FocusManager.instance.primaryFocus?.unfocus();
    final pinned = messages.where((m) => pinnedMessageIds.contains(m.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.55,
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 26 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))),
            SizedBox(height: 18),
            Text('Pinned messages', style: TextStyle(color: theme.text, fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Expanded(
              child: pinned.isEmpty
                  ? Center(child: Text('No pinned messages yet', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w800)))
                  : ListView.builder(
                      itemCount: pinned.length,
                      itemBuilder: (_, i) => Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(color: theme.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pinned[i].senderName, style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text(pinned[i].text, style: TextStyle(color: theme.text, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void showGifSheet(PrivateChatTheme theme) {
    FocusManager.instance.primaryFocus?.unfocus();
    final gifs = ['happy dance', 'anime shock', 'typing fast', 'mission passed', 'bruh moment', 'demon mode'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 26 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))),
          SizedBox(height: 18),
          Text('GIF', style: TextStyle(color: theme.text, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: gifs.map((g) => ActionChip(label: Text(g), avatar: Icon(Icons.gif_box_rounded), onPressed: () => sendGif(g))).toList()),
        ]),
      ),
    );
  }

  static const List<String> skinTones = ['', '🏻', '🏼', '🏽', '🏾', '🏿'];

  List<String> withSkinTones(List<String> bases) {
    return bases.map((base) => selectedSkinTone.isEmpty ? base : '$base$selectedSkinTone').toList();
  }

  bool canUseSkinTone(String emoji) {
    final clean = emoji.replaceAll(RegExp(r'[🏻🏼🏽🏾🏿]'), '');
    const bases = ['👋','🤚','🖐','✋','🖖','🫱','🫲','🫳','🫴','👌','🤌','🤏','✌','🤞','🫰','🤟','🤘','🤙','👈','👉','👆','🖕','👇','☝','👍','👎','✊','👊','🤛','🤜','👏','🙌','🫶','👐','🤲','🤝','🙏','✍','💅','🤳','💪','🦵','🦶','👂','🦻','👃','👶','🧒','👦','👧','🧑','👨','👩','🧔','👱','👴','👵','🙍','🙎','🙅','🙆','💁','🙋','🧏','🙇','🤦','🤷','👮','🕵','💂','🥷','👷','🫅','🤴','👸','👳','👲','🧕','🤵','👰','🤰','🫃','🫄','👩‍🍼','🧑‍🍼','👨‍🍼','🧙','🧚','🧛','🧜','🧝','💆','💇','🚶','🧍','🧎','🏃','💃','🕺','🕴','🧖','🧗','🏇','⛷','🏂','🏌','🏄','🚣','🏊','⛹','🏋','🚴','🚵','🤸','🤼','🤽','🤾','🤹','🧘','🛀','🛌'];
    return bases.contains(clean) || clean.startsWith('🧑‍');
  }

  void showSkinTonePicker(String emoji, PrivateChatTheme theme) {
    if (!canUseSkinTone(emoji)) {
      insertTextAtCursor(emoji);
      return;
    }

    final base = emoji.replaceAll(RegExp(r'[🏻🏼🏽🏾🏿]'), '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 22 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))),
              SizedBox(height: 14),
              Text('Choose default skin tone', style: TextStyle(color: theme.text, fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('This changes all skin-tone emojis in the emoji keyboard.', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
              SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: skinTones.map((tone) {
                final value = tone.isEmpty ? base : '$base$tone';
                final selected = selectedSkinTone == tone;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => selectedSkinTone = tone);
                    LocalStore.setString('emoji_skin_tone', tone);
                    Navigator.pop(context);
                    insertTextAtCursor(value);
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? theme.primary.withOpacity(0.18) : theme.inputFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? theme.primary : theme.border),
                    ),
                    child: Text(value, style: TextStyle(fontSize: 26)),
                  ),
                );
              }).toList()),
            ]),
          ),
        ),
      ),
    );
  }

  IconData emojiIconFor(String name) {
    switch (name) {
      case 'Recent':
        return Icons.schedule_rounded;
      case 'Smileys':
        return Icons.emoji_emotions_rounded;
      case 'People':
        return Icons.back_hand_rounded;
      case 'Love':
        return Icons.favorite_rounded;
      case 'Memes / Vibe':
        return Icons.bolt_rounded;
      case 'Animals':
        return Icons.pets_rounded;
      case 'Food':
        return Icons.fastfood_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Activities':
        return Icons.sports_esports_rounded;
      case 'Objects':
        return Icons.lightbulb_rounded;
      case 'Symbols':
        return Icons.favorite_rounded;
      case 'Flags':
        return Icons.flag_rounded;
      default:
        return Icons.emoji_emotions_rounded;
    }
  }


  String _flagFromCode(String code) {
    final upper = code.toUpperCase();
    if (upper.length != 2) return '';
    final first = upper.codeUnitAt(0) - 65 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }

  List<String> get countryFlags {
    const codes = [
      'AC','AD','AE','AF','AG','AI','AL','AM','AO','AQ','AR','AS','AT','AU','AW','AX','AZ',
      'BA','BB','BD','BE','BF','BG','BH','BI','BJ','BL','BM','BN','BO','BQ','BR','BS','BT','BV','BW','BY','BZ',
      'CA','CC','CD','CF','CG','CH','CI','CK','CL','CM','CN','CO','CP','CR','CU','CV','CW','CX','CY','CZ',
      'DE','DG','DJ','DK','DM','DO','DZ','EA','EC','EE','EG','EH','ER','ES','ET','EU','FI','FJ','FK','FM','FO','FR',
      'GA','GB','GD','GE','GF','GG','GH','GI','GL','GM','GN','GP','GQ','GR','GS','GT','GU','GW','GY',
      'HK','HM','HN','HR','HT','HU','IC','ID','IE','IL','IM','IN','IO','IQ','IR','IS','IT',
      'JE','JM','JO','JP','KE','KG','KH','KI','KM','KN','KP','KR','KW','KY','KZ',
      'LA','LB','LC','LI','LK','LR','LS','LT','LU','LV','LY','MA','MC','MD','ME','MF','MG','MH','MK','ML','MM','MN','MO','MP','MQ','MR','MS','MT','MU','MV','MW','MX','MY','MZ',
      'NA','NC','NE','NF','NG','NI','NL','NO','NP','NR','NU','NZ','OM','PA','PE','PF','PG','PH','PK','PL','PM','PN','PR','PS','PT','PW','PY','QA',
      'RE','RO','RS','RU','RW','SA','SB','SC','SD','SE','SG','SH','SI','SJ','SK','SL','SM','SN','SO','SR','SS','ST','SV','SX','SY','SZ',
      'TA','TC','TD','TF','TG','TH','TJ','TK','TL','TM','TN','TO','TR','TT','TV','TW','TZ','UA','UG','UM','UN','US','UY','UZ',
      'VA','VC','VE','VG','VI','VN','VU','WF','WS','XK','YE','YT','ZA','ZM','ZW'
    ];
    return codes.map(_flagFromCode).where((flag) => flag.isNotEmpty).toList();
  }

  Map<String, List<String>> get emojiCategories => {
        'Recent': recentEmojis.isEmpty ? ['😂', '😭', '🔥', '💀', '❤️', '👍', '🥲', '😤', '👀', '✨', '🙏', '🗿'] : recentEmojis,
        'Smileys': ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '🫠', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🫢', '🫣', '🤫', '🤔', '🫡', '🤐', '🤨', '😐', '😑', '😶', '🫥', '😏', '😒', '🙄', '😬', '😮‍💨', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '😵‍💫', '🤯', '🤠', '🥳', '🥸', '😎', '🤓', '🧐', '😕', '🫤', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳', '🥺', '🥹', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈', '👿', '💀', '☠️', '💩', '🤡', '👹', '👺', '👻', '👽', '👾', '🤖', '😶‍🌫️', '🙂‍↔️', '🙂‍↕️', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'],
        'People': [
          ...withSkinTones(['👋', '🤚', '🖐', '✋', '🖖', '🫱', '🫲', '🫳', '🫴', '👌', '🤌', '🤏', '✌', '🤞', '🫰', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '🫶', '👐', '🤲', '🤝', '🙏', '✍', '💅', '🤳', '💪', '🦵', '🦶', '👂', '🦻', '👃']),
          '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁', '👅', '👄', '🫦',
          ...withSkinTones(['👶', '🧒', '👦', '👧', '🧑', '👨', '👩', '🧔', '👱', '👴', '👵', '🙍', '🙎', '🙅', '🙆', '💁', '🙋', '🧏', '🙇', '🤦', '🤷', '🧑‍⚕️', '🧑‍🎓', '🧑‍🏫', '🧑‍⚖️', '🧑‍🌾', '🧑‍🍳', '🧑‍🔧', '🧑‍🏭', '🧑‍💼', '🧑‍🔬', '🧑‍💻', '🧑‍🎤', '🧑‍🎨', '🧑‍✈️', '🧑‍🚀', '🧑‍🚒', '👮', '🕵', '💂', '🥷', '👷', '🫅', '🤴', '👸', '👳', '👲', '🧕', '🤵', '👰', '🤰', '🫃', '🫄', '👩‍🍼', '🧑‍🍼', '👨‍🍼', '🧙', '🧚', '🧛', '🧜', '🧝', '🧞', '🧟', '💆', '💇', '🚶', '🧍', '🧎', '🏃', '💃', '🕺', '🕴', '👯', '🧖', '🧗', '🤺', '🏇', '⛷', '🏂', '🏌', '🏄', '🚣', '🏊', '⛹', '🏋', '🚴', '🚵', '🤸', '🤼', '🤽', '🤾', '🤹', '🧘', '🛀', '🛌']),
          '👫', '👬', '👭', '💏', '💑', '👨‍👩‍👧', '👨‍👩‍👦', '👩‍👩‍👧', '👨‍👨‍👦', '👪', '🗣', '👤', '👥', '🫂', '👣'
        ],
        'Animals': ['💐', '🌸', '💮', '🪷', '🏵️', '🌹', '🥀', '🌺', '🌻', '🌼', '🌷', '🪻', '☘️', '🍀', '🌿', '🌱', '🌲', '🌳', '🌴', '🌵', '🌾', '🍁', '🍂', '🍃', '🪴', '🪹', '🪺', '🪨', '⛰️', '🏔️', '❄️', '☃️', '⛄', '🌡️', '🔥', '🌋', '🏜️', '🏞️', '🌅', '🌄', '🏝️', '🏖️', '🌊', '💨', '🌬️', '🌀', '🌪️', '⚡', '☔', '☂️', '🌈', '💧', '☁️', '🌨️', '🌧️', '⛈️', '🌩️', '🌦️', '⛅', '🌤️', '☀️', '🌞', '🌝', '🌚', '🌛', '🌜', '🌙', '⭐', '🌟', '✨', '🪐', '🌍', '🌎', '🌏', '🌌', '☄️', '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘', '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨', '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒', '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🪱', '🐛', '🦋', '🐌', '🐞', '🐜', '🪰', '🪲', '🪳', '🦟', '🦗', '🕷️', '🦂', '🐢', '🐍', '🦎', '🦖', '🦕', '🐙', '🦑', '🦐', '🦞', '🦀', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧', '🦣', '🐘', '🦏', '🦛', '🐪', '🐫', '🦒', '🦘', '🦬', '🐃', '🐂', '🐄', '🐎', '🐖', '🐏', '🐑', '🦙', '🐐', '🦌', '🐕', '🐩', '🦮', '🐕‍🦺', '🐈', '🐈‍⬛', '🪶', '🐓', '🦃', '🦤', '🦚', '🦜', '🦢', '🦩', '🕊️', '🐇', '🦝', '🦨', '🦡', '🦫', '🦦', '🦥', '🐁', '🐀', '🐿️', '🦔'],
        'Food': ['🍏', '🍎', '🍐', '🍊', '🍋', '🍋‍🟩', '🍌', '🍉', '🍇', '🍓', '🫐', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🫛', '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅', '🥔', '🍠', '🫚', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳', '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🦴', '🌭', '🍔', '🍟', '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗', '🥘', '🫕', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🦪', '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍢', '🍡', '🍧', '🍨', '🍦', '🥧', '🧁', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🌰', '🥜', '🫘', '🍯', '🥛', '🍼', '🫖', '☕', '🍵', '🧃', '🥤', '🧋', '🧉', '🧊', '🥢', '🍽️', '🍴', '🥄'],
        'Travel': ['🌍', '🌎', '🌏', '🌐', '🗺️', '🧭', '🏔️', '⛰️', '🌋', '🗻', '🏕️', '🏖️', '🏜️', '🏝️', '🏞️', '🏟️', '🏛️', '🏗️', '🧱', '🪨', '🪵', '🛖', '🏘️', '🏚️', '🏠', '🏡', '🏢', '🏣', '🏤', '🏥', '🏦', '🏨', '🏪', '🏫', '🏬', '🏭', '🏯', '🏰', '💒', '🗼', '🗽', '⛪', '🕌', '🛕', '🕍', '⛩️', '🕋', '⛲', '⛺', '🌁', '🌃', '🏙️', '🌄', '🌅', '🌆', '🌇', '🌉', '♨️', '🎠', '🛝', '🎡', '🎢', '💈', '🎪', '🚂', '🚃', '🚄', '🚅', '🚆', '🚇', '🚈', '🚉', '🚊', '🚝', '🚞', '🚋', '🚌', '🚍', '🚎', '🚐', '🚑', '🚒', '🚓', '🚔', '🚕', '🚖', '🚗', '🚘', '🚙', '🛻', '🚚', '🚛', '🚜', '🏎️', '🏍️', '🛵', '🦽', '🦼', '🛺', '🚲', '🛴', '🛹', '🛼', '🚏', '🛣️', '🛤️', '🛢️', '⛽', '🛞', '🚨', '🚥', '🚦', '🛑', '🚧', '⚓', '🛟', '⛵', '🛶', '🚤', '🛳️', '⛴️', '🛥️', '🚢', '✈️', '🛩️', '🛫', '🛬', '🪂', '💺', '🚁', '🚟', '🚠', '🚡', '🛰️', '🚀', '🛸'],
        'Activities': ['⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛼', '🛷', '⛸️', '🥌', '🎿', '⛷️', '🏂', '🪂', '🏋️', '🤼', '🤸', '⛹️', '🤺', '🤾', '🏌️', '🏇', '🧘', '🏄', '🏊', '🤽', '🚣', '🧗', '🚵', '🚴', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️', '🎪', '🤹', '🎭', '🩰', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🪘', '🎷', '🎺', '🪗', '🎸', '🪕', '🎻', '🪈', '🎲', '♟️', '🎯', '🎳', '🎮', '🎰', '🧩'],
        'Objects': ['⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️', '🗜️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳', '📡', '🔋', '🪫', '🔌', '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸', '💵', '💴', '💶', '💷', '🪙', '💰', '💳', '🪪', '💎', '⚖️', '🪜', '🧰', '🪛', '🔧', '🔨', '⚒️', '🛠️', '⛏️', '🪚', '🔩', '⚙️', '🪤', '🧱', '⛓️', '🧲', '🪝', '🧪', '🧫', '🧬', '🔬', '🔭', '📿', '🧿', '🔮', '🪬', '💈', '⚗️', '🕳️', '🩹', '🩺', '💊', '💉', '🩸', '🧸', '🪆', '🖼️', '🪞', '🪟', '🛍️', '🛒', '🎁', '🎈', '🎏', '🎀', '🪄', '🪅', '🪩', '🎊', '🎉', '🎎', '🏮', '🎐', '🧧', '✉️', '📩', '📨', '📧', '💌', '📥', '📤', '📦', '🏷️', '📪', '📫', '📬', '📭', '📮', '📯', '📜', '📃', '📄', '📑', '🧾', '📊', '📈', '📉', '🗒️', '🗓️', '📆', '📅', '🗑️', '📇', '🗃️', '🗳️', '🗄️', '📋', '📁', '📂', '🗂️', '🗞️', '📰', '📓', '📔', '📒', '📕', '📗', '📘', '📙', '📚', '📖', '🔖', '🧷', '🔗', '📎', '🖇️', '📐', '📏', '🧮', '📌', '📍', '✂️', '🖊️', '🖋️', '✒️', '🖌️', '🖍️', '📝', '✏️', '🔍', '🔎', '🔏', '🔐', '🔒', '🔓'],
        'Symbols': ['❤️', '🧡', '💛', '💚', '💙', '🩵', '💜', '🖤', '🩶', '🤍', '🤎', '💔', '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️', '📴', '📳', '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️', '㊗️', '🈴', '🈵', '🈹', '🈲', '🅰️', '🅱️', '🆎', '🆑', '🅾️', '🆘', '❌', '⭕', '🛑', '⛔', '📛', '🚫', '💯', '💢', '♨️', '🚷', '🚯', '🚳', '🚱', '🔞', '📵', '🚭', '❗', '❕', '❓', '❔', '‼️', '⁉️', '🔅', '🔆', '〽️', '⚠️', '🚸', '🔱', '⚜️', '🔰', '♻️', '✅', '🈯', '💹', '❇️', '✳️', '❎', '🌐', '💠', 'Ⓜ️', '🌀', '💤', '🏧', '🚾', '♿', '🅿️', '🛗', '🈳', '🈂️', '🛂', '🛃', '🛄', '🛅', '🚹', '🚺', '🚼', '⚧️', '🚻', '🚮', '🎦', '📶', '🈁', '🔣', 'ℹ️', '🔤', '🔡', '🔠', '🆖', '🆗', '🆙', '🆒', '🆕', '🆓', '0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟', '🔢', '#️⃣', '*️⃣', '⏏️', '▶️', '⏸️', '⏯️', '⏹️', '⏺️', '⏭️', '⏮️', '⏩', '⏪', '⏫', '⏬', '◀️', '🔼', '🔽', '➡️', '⬅️', '⬆️', '⬇️', '↗️', '↘️', '↙️', '↖️', '↕️', '↔️', '↪️', '↩️', '⤴️', '⤵️', '🔀', '🔁', '🔂', '🔄', '🔃', '🎵', '🎶', '➕', '➖', '➗', '✖️', '🟰', '♾️', '💲', '💱', '™️', '©️', '®️', '〰️', '➰', '➿', '🔚', '🔙', '🔛', '🔝', '🔜', '✔️', '☑️', '🔘', '🔴', '🟠', '🟡', '🟢', '🔵', '🟣', '⚫', '⚪', '🟤', '🔺', '🔻', '🔸', '🔹', '🔶', '🔷', '🔳', '🔲', '▪️', '▫️', '◾', '◽', '◼️', '◻️', '🟥', '🟧', '🟨', '🟩', '🟦', '🟪', '⬛', '⬜', '🟫'],
        'Flags': ['🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🏳️‍⚧️', '🏴‍☠️', ...countryFlags],
      };

  void insertTextAtCursor(String value) {
    rememberEmoji(value);
    final text = messageController.text;
    final selection = messageController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, value);
    messageController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: start + value.length));
  }


  void deleteLastText() {
    final text = messageController.text;
    final selection = messageController.selection;
    if (text.isEmpty) return;
    final cursor = selection.start < 0 ? text.length : selection.start;
    if (cursor <= 0) return;

    // Simple backspace for UI. It removes one UTF-16 cluster safely enough for normal text/emojis.
    final before = text.substring(0, cursor);
    final after = text.substring(selection.end < 0 ? cursor : selection.end);
    final newBefore = before.characters.skipLast(1).toString();
    final newOffset = newBefore.length;
    messageController.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void openNormalKeyboard() {
    setState(() {
      showEmojiPanel = false;
      showGifKeyboard = false;
    });
    messageFocusNode.requestFocus();
  }

  void openEmojiKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      showEmojiPanel = true;
      showGifKeyboard = false;
    });
  }

  void openGifKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      showGifKeyboard = true;
      showEmojiPanel = false;
    });
  }

  Widget buildComposer(PrivateChatTheme theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: theme.background, border: Border(top: BorderSide(color: theme.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (replyTarget != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.border)),
            child: Row(children: [
              Container(width: 4, height: 38, decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(999))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Replying to ${replyTarget!.senderName}', style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text(replyTarget!.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.muted)),
              ])),
              IconButton(onPressed: () => setState(() => replyTarget = null), icon: Icon(Icons.close_rounded, color: theme.text)),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: theme.inputFill, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.border)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  onPressed: (showEmojiPanel || showGifKeyboard) ? openNormalKeyboard : openEmojiKeyboard,
                  icon: Icon((showEmojiPanel || showGifKeyboard) ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: theme.muted),
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    focusNode: messageFocusNode,
                    style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
                    cursorColor: theme.primary,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 6,
                    onTap: () => setState(() { showEmojiPanel = false; showGifKeyboard = false; }),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: theme.muted, fontWeight: FontWeight.w700),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(onPressed: openGifKeyboard, icon: Icon(Icons.gif_box_rounded, color: showGifKeyboard ? theme.primary : theme.muted)),
              ]),
            ),
          ),
          SizedBox(width: 8),
          IconButton.filled(onPressed: sendMessage, icon: Icon(Icons.send_rounded), style: IconButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white)),
        ]),
        if (showEmojiPanel) buildEmojiKeyboard(theme),
        if (showGifKeyboard) buildGifKeyboard(theme),
      ]),
    );
  }

  Widget buildEmojiKeyboard(PrivateChatTheme theme) {
    final allCategories = emojiCategories;
    final names = allCategories.keys.toList();
    final query = emojiSearchText.trim().toLowerCase();

    final categories = <String, List<String>>{};

    if (query.isEmpty) {
      for (final name in names) {
        categories[name] = allCategories[name]!;
      }
    } else {
      // Search is global, not category based.
      // So typing "liberty" can find 🗽, "party" can find 🎉 🥳 🎊 🎂 etc.
      final allEmojiSet = <String>{};
      for (final list in allCategories.values) {
        allEmojiSet.addAll(list);
      }

      final filtered = allEmojiSet
          .where((emoji) => emojiMatchesSearch(emoji, 'all emojis', query))
          .toList()
        ..sort((a, b) => _emojiSearchScore(b, query).compareTo(_emojiSearchScore(a, query)));

      if (filtered.isNotEmpty) categories['Search Results'] = filtered;
    }

    final visibleNames = categories.keys.toList();

    return Container(
      height: 385,
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            controller: emojiSearchController,
            style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
            cursorColor: theme.primary,
            onChanged: (value) => setState(() => emojiSearchText = value),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: theme.muted),
              suffixIcon: emojiSearchText.isEmpty ? null : IconButton(
                icon: Icon(Icons.close_rounded, color: theme.muted),
                onPressed: () => setState(() { emojiSearchText = ''; emojiSearchController.clear(); }),
              ),
              hintText: 'Search emojis like party, liberty, love',
              hintStyle: TextStyle(color: theme.muted, fontWeight: FontWeight.w700),
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: theme.primary.withOpacity(0.45))),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: Row(children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: names.length,
                itemBuilder: (context, index) {
                  final selected = selectedEmojiCategory == index;
                  return Tooltip(
                    message: names[index],
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => selectedEmojiCategory = index);
                        final visibleIndex = visibleNames.indexOf(names[index]);
                        if (visibleIndex < 0) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final keyContext = emojiCategoryKeys[index].currentContext;
                          if (keyContext != null) {
                            Scrollable.ensureVisible(
                              keyContext,
                              duration: Duration(milliseconds: 1),
                              alignment: 0.02,
                            );
                          }
                        });
                      },
                      child: Container(
                        width: 44,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: selected ? theme.primary.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(emojiIconFor(names[index]), color: selected ? theme.primary : theme.muted, size: 22),
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: deleteLastText,
              icon: Icon(Icons.backspace_rounded, color: theme.muted),
            ),
          ]),
        ),
        Divider(height: 1, color: theme.border),
        Expanded(
          child: categories.isEmpty
              ? Center(child: Text('No emojis found', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w800)))
              : CustomScrollView(
                  controller: emojiScrollController,
                  cacheExtent: 900,
                  slivers: [
                    for (final name in visibleNames) ...[
                      SliverToBoxAdapter(
                        key: emojiCategoryKeys[names.indexOf(name)],
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Text(name, style: TextStyle(color: theme.text, fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final emoji = categories[name]![index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => insertTextAtCursor(emoji),
                                onLongPress: () => showSkinTonePicker(emoji, theme),
                                child: Center(child: Text(emoji, style: TextStyle(fontSize: 25))),
                              );
                            },
                            childCount: categories[name]!.length,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 14)),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  int _emojiSearchScore(String emoji, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final haystack = emojiSearchKeywords(emoji, 'all emojis');
    var score = 0;

    if (emoji == query) score += 10000;
    if (haystack.contains(' ${query} ')) score += 900;
    if (haystack.startsWith(query)) score += 700;
    if (haystack.contains(query)) score += 350;

    final typedWords = query.split(RegExp(r'\s+')).where((word) => word.trim().isNotEmpty);
    for (final word in typedWords) {
      if (haystack.contains(' ${word} ')) score += 180;
      if (haystack.contains(word)) score += 80;
      final related = emojiRelatedSearchWords[word] ?? const <String>[];
      for (final extraWord in related) {
        if (haystack.contains(' ${extraWord} ')) score += 45;
        if (haystack.contains(extraWord)) score += 20;
      }
    }
    return score;
  }

  bool emojiMatchesSearch(String emoji, String category, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final haystack = emojiSearchKeywords(emoji, category);
    final typedWords = query.split(RegExp(r'\s+')).where((word) => word.trim().isNotEmpty).toList();

    // Smart search rule:
    // Each word the user typed must match either the emoji name/keywords directly,
    // or one of that word's related meanings.
    // Example: "party" can match confetti, birthday, cake, gift, balloon, music, dance.
    return typedWords.every((word) {
      final related = emojiRelatedSearchWords[word] ?? const <String>[];
      if (_emojiWordMatches(haystack, word) || emoji.contains(word)) return true;
      return related.any((extraWord) => _emojiWordMatches(haystack, extraWord));
    });
  }

  bool _emojiWordMatches(String haystack, String word) {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return true;
    if (haystack.contains(cleanWord)) return true;

    // Tiny fuzzy match for small spelling mistakes.
    // Example: "liberti" can still find "liberty".
    if (cleanWord.length < 4) return false;
    final words = haystack.split(RegExp(r'[^a-z0-9]+')).where((item) => item.length >= 4);
    for (final target in words) {
      if ((target.length - cleanWord.length).abs() > 2) continue;
      if (_smallEditDistance(cleanWord, target) <= 1) return true;
    }
    return false;
  }

  int _smallEditDistance(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 1) return 99;

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a.codeUnitAt(i) == b.codeUnitAt(j)) {
        i++;
        j++;
      } else {
        edits++;
        if (edits > 1) return edits;
        if (a.length > b.length) {
          i++;
        } else if (b.length > a.length) {
          j++;
        } else {
          i++;
          j++;
        }
      }
    }
    if (i < a.length || j < b.length) edits++;
    return edits;
  }

  String emojiCountrySearchWords(String emoji) {
    // Country/flag keywords are already included in emojiSearchIndex.
    // This keeps the search function safe even when no extra country mapper is needed.
    return '';
  }

  String emojiSearchKeywords(String emoji, String category) {
    final lowerCategory = category.toLowerCase();
    final base = emoji.replaceAll(RegExp(r'[🏻🏼🏽🏾🏿]'), '');
    final words = <String>[
      emoji,
      base,
      lowerCategory,
      _categorySearchWords(lowerCategory),
      emojiSearchIndex[base] ?? '',
      emojiCountrySearchWords(base),
      _emojiAliasWords(base),
      _emojiGroupWords(base),
    ];
    return words.join(' ').toLowerCase();
  }

  String _categorySearchWords(String category) {
    if (category.contains('recent')) return 'recent latest used history';
    if (category.contains('smile')) return 'face faces smiley emotion reaction expression happy sad angry laugh cry';
    if (category.contains('people')) return 'people hand hands body person human skin tone gesture family job profession';
    if (category.contains('love')) return 'love heart romance romantic crush couple cute kiss valentine affection care';
    if (category.contains('meme') || category.contains('vibe')) return 'meme memes vibe sigma attitude cool reaction troll savage bro skull fire';
    if (category.contains('animal')) return 'animal animals pet pets nature creature wild';
    if (category.contains('food')) return 'food drink fruit vegetable snack meal restaurant hungry';
    if (category.contains('travel')) return 'travel place destination vehicle transport building map road space';
    if (category.contains('activities')) return 'activity activities sport game music art fun trophy';
    if (category.contains('objects')) return 'object tool phone computer file camera money mail book';
    if (category.contains('symbols')) return 'symbol sign arrow shape number heart warning check cross';
    if (category.contains('flags')) return 'flag country nation india usa uk';
    return category;
  }

  String _emojiGroupWords(String emoji) {
    const love = {'❤️','🧡','💛','💚','💙','🩵','💜','🖤','🩶','🤍','🤎','💔','❤️‍🔥','❤️‍🩹','❣️','💕','💞','💓','💗','💖','💘','💝','💟','😍','🥰','😘','😚','😙','🫶','💌','🌹','💏','💑','🫂'};
    const sad = {'😢','😭','😞','😔','🥲','😿','💔','😟','🙁','☹️','😥','😓','😩','😫','🥺','🥹'};
    const happy = {'😀','😃','😄','😁','😆','😅','😂','🤣','🙂','😊','😇','🥳','😺','😸','😹'};
    const angry = {'😡','😠','🤬','😤','👿','😈','💢'};
    const scared = {'😨','😰','😱','😧','😦','😵','😵‍💫','🤯'};
    const sigma = {'🗿','🤫','🧏','😎','😏','😐','😑','🫡','💀','☠️','🤡','👑','🐺','🔥','🥶','😈','👿','🧠','💯','⚡','🦅','🍷'};
    const yes = {'✅','✔️','☑️','👍','👌','🆗','🙆','👏','💯'};
    const no = {'❌','✖️','❎','👎','🚫','⛔','🙅','🛑'};
    const fire = {'🔥','❤️‍🔥','🚒','🧯','🌋','🥵','⚡'};
    const sleep = {'😴','🥱','💤','🛌','🛏️'};
    const sick = {'😷','🤒','🤕','🤢','🤮','🤧','💊','💉','🩺'};
    const money = {'💸','💵','💴','💶','💷','🪙','💰','💳','💎'};
    const tech = {'📱','📲','💻','⌨️','🖥️','🖨️','🖱️','🔋','🔌','📡','🔒','🔓','🔐','🔏'};
    const games = {'🎮','🕹️','🎲','♟️','🎯','🎳','🎰','🧩'};
    const music = {'🎵','🎶','🎤','🎧','🎼','🎹','🥁','🎷','🎺','🎸','🎻'};
    const travel = {'🌍','🌎','🌏','🌐','🗺️','🧭','✈️','🚀','🚗','🏍️','🚂','🚌','🚢','🏠','🏡','🏢'};
    const animals = {'🐶','🐱','🐺','🦁','🐯','🐼','🐵','🙈','🙉','🙊','🐸','🦊','🐻','🐰','🐍','🦋','🐦','🐟'};

    final chunks = <String>[];
    if (love.contains(emoji)) chunks.add('love heart romance romantic crush cute kiss affection valentine care');
    if (sad.contains(emoji)) chunks.add('sad cry crying tears pain broken depressed upset lonely emotional');
    if (happy.contains(emoji)) chunks.add('happy smile laugh funny joy lol lmao excited');
    if (angry.contains(emoji)) chunks.add('angry mad rage furious annoyed pissed');
    if (scared.contains(emoji)) chunks.add('scared fear shock shocked surprised danger anxiety');
    if (sigma.contains(emoji)) chunks.add('sigma meme vibe cool savage attitude mewing mog stone face moyai bro');
    if (yes.contains(emoji)) chunks.add('yes ok okay correct done agree like approve good');
    if (no.contains(emoji)) chunks.add('no wrong cancel stop reject dislike bad');
    if (fire.contains(emoji)) chunks.add('fire hot lit flame burn danger');
    if (sleep.contains(emoji)) chunks.add('sleep tired bored sleepy night rest');
    if (sick.contains(emoji)) chunks.add('sick ill medicine hospital vomit fever');
    if (money.contains(emoji)) chunks.add('money cash rich payment bank price diamond');
    if (tech.contains(emoji)) chunks.add('tech phone laptop computer keyboard battery lock security');
    if (games.contains(emoji)) chunks.add('game gaming play controller arcade');
    if (music.contains(emoji)) chunks.add('music song audio sound sing');
    if (travel.contains(emoji)) chunks.add('travel destination place vehicle transport trip');
    if (animals.contains(emoji)) chunks.add('animal pet wild nature');
    return chunks.join(' ');
  }

  String _emojiAliasWords(String emoji) {
    final Map<String, String> known = {
      '😀': 'grinning face smile happy',
      '😃': 'smiley face happy open mouth',
      '😄': 'smile eyes happy laugh',
      '😁': 'grin teeth happy',
      '😆': 'laugh squint happy',
      '😅': 'sweat smile awkward relief',
      '🤣': 'rolling laughing floor lol rofl',
      '😂': 'laugh tears joy funny lol lmao',
      '🙂': 'slight smile okay fine',
      '🙃': 'upside down sarcasm silly',
      '🫠': 'melting awkward embarrassed heat',
      '😉': 'wink joke flirt',
      '😊': 'blush smile cute happy',
      '😇': 'angel innocent',
      '🥰': 'smiling hearts love cute affection',
      '😍': 'heart eyes love crush cute',
      '🤩': 'star eyes impressed wow',
      '😘': 'kiss heart love',
      '😗': 'kiss',
      '😚': 'closed eye kiss love',
      '😙': 'smiling kiss love',
      '🥲': 'happy tear sad proud emotional',
      '😋': 'yum tasty food tongue',
      '😛': 'tongue playful',
      '😜': 'wink tongue silly',
      '🤪': 'crazy goofy zany',
      '😝': 'squint tongue joke',
      '🤑': 'money face rich cash',
      '🤗': 'hug hugging',
      '🤭': 'hand mouth shy oops',
      '🫢': 'gasp shocked mouth',
      '🫣': 'peek shy scared',
      '🤫': 'shush quiet secret sigma',
      '🤔': 'thinking hmm doubt',
      '🫡': 'salute respect sir yes',
      '🤐': 'zip mouth secret silent',
      '🤨': 'raised eyebrow doubt suspicious',
      '😐': 'neutral deadpan sigma',
      '😑': 'expressionless blank sigma',
      '😶': 'no mouth silent',
      '😏': 'smirk sigma flirt attitude',
      '😒': 'unamused annoyed',
      '🙄': 'eye roll annoyed',
      '😬': 'grimace awkward',
      '😌': 'relieved calm',
      '😔': 'sad pensive',
      '😪': 'sleepy tired',
      '🤤': 'drool hungry',
      '😴': 'sleep tired zzz',
      '😷': 'mask sick',
      '🤒': 'fever sick thermometer',
      '🤕': 'hurt bandage',
      '🤢': 'nausea sick',
      '🤮': 'vomit puke sick',
      '🤧': 'sneeze sick',
      '🥵': 'hot heat sweating',
      '🥶': 'cold freezing ice sigma',
      '🥴': 'woozy drunk dizzy',
      '🤯': 'mind blown shock',
      '🤠': 'cowboy',
      '🥳': 'party celebrate birthday',
      '🥸': 'disguise glasses',
      '😎': 'cool sunglasses sigma',
      '🤓': 'nerd study',
      '🧐': 'monocle inspect',
      '😕': 'confused',
      '🫤': 'confused unsure meh',
      '😟': 'worried',
      '🙁': 'frown sad',
      '😮': 'wow surprised open mouth',
      '😯': 'hushed surprised',
      '😲': 'astonished shocked',
      '😳': 'flushed embarrassed',
      '🥺': 'pleading puppy eyes please',
      '🥹': 'holding tears emotional',
      '😨': 'fear scared',
      '😰': 'anxious sweat scared',
      '😥': 'sad sweat relief',
      '😢': 'cry tear sad',
      '😭': 'sob crying sad tears',
      '😱': 'scream fear shock',
      '😖': 'confounded upset',
      '😣': 'persevere upset',
      '😞': 'disappointed sad',
      '😓': 'downcast sweat sad',
      '😩': 'weary tired sad',
      '😫': 'tired exhausted',
      '🥱': 'yawn bored sleepy',
      '😤': 'triumph annoyed angry',
      '😡': 'rage angry red',
      '😠': 'angry mad',
      '🤬': 'swear angry curse',
      '💀': 'skull dead funny meme',
      '☠️': 'skull crossbones danger pirate dead',
      '💩': 'poop shit funny',
      '🤡': 'clown fool meme',
      '👻': 'ghost scary',
      '👽': 'alien',
      '👾': 'space invader game alien',
      '🤖': 'robot bot ai',
      '🗿': 'moyai stone face sigma meme',
      '🧏': 'deaf mewing sigma',
      '👋': 'wave hello bye hand',
      '👌': 'ok perfect hand',
      '👏': 'clap applause hand',
      '💪': 'muscle strong gym power',
      '🤝': 'handshake deal agreement',
      '🙏': 'pray please thanks namaste',
      '👍': 'thumbs up like yes good',
      '👎': 'thumbs down dislike no bad',
      '👀': 'eyes look see watching',
      '🧠': 'brain smart mind',
      '🫀': 'heart organ health',
      '👄': 'lips mouth kiss',
      '🫦': 'biting lip flirt',
      '🐶': 'dog pet animal',
      '🐱': 'cat pet animal',
      '🐺': 'wolf sigma animal',
      '🦁': 'lion king animal',
      '🐯': 'tiger animal',
      '🐼': 'panda animal cute',
      '🐵': 'monkey animal',
      '🙈': 'see no evil monkey shy',
      '🙉': 'hear no evil monkey',
      '🙊': 'speak no evil monkey secret',
      '🦋': 'butterfly beautiful nature',
      '🍕': 'pizza food',
      '🍔': 'burger food',
      '🍟': 'fries food',
      '🌮': 'taco food',
      '🍰': 'cake dessert sweet',
      '🎂': 'birthday cake',
      '☕': 'coffee tea drink',
      '🍵': 'tea drink',
      '🥤': 'drink soda',
      '⚽': 'football soccer sport',
      '🏏': 'cricket sport',
      '🎮': 'game controller gaming',
      '🎯': 'target aim',
      '🏆': 'trophy winner',
      '🎵': 'music note song',
      '🎶': 'music notes song',
      '📱': 'phone mobile',
      '💻': 'laptop computer coding',
      '🔒': 'lock private security',
      '🔓': 'unlock open',
      '📷': 'camera photo',
      '🎥': 'video camera movie',
      '✉️': 'mail email letter',
      '💌': 'love letter mail heart',
      '💸': 'money wings cash spend',
      '💰': 'money bag cash rich',
      '💳': 'card payment',
      '💎': 'diamond rich',
      '❤️': 'red heart love',
      '🧡': 'orange heart love',
      '💛': 'yellow heart love',
      '💚': 'green heart love',
      '💙': 'blue heart love',
      '🩵': 'light blue heart love',
      '💜': 'purple heart love',
      '🖤': 'black heart love',
      '🩶': 'grey heart love',
      '🤍': 'white heart love',
      '🤎': 'brown heart love',
      '💔': 'broken heart sad breakup',
      '❤️‍🔥': 'heart on fire love passion',
      '❤️‍🩹': 'healing heart recover',
      '💕': 'two hearts love',
      '💞': 'revolving hearts love',
      '💓': 'beating heart love',
      '💗': 'growing heart love',
      '💖': 'sparkling heart love',
      '💘': 'heart arrow cupid love',
      '💝': 'heart gift love',
      '💯': 'hundred perfect yes',
      '✅': 'check correct yes done',
      '❌': 'cross wrong no cancel',
      '⚠️': 'warning alert danger',
      '🔥': 'fire hot lit',
      '⚡': 'lightning power energy',
      '✨': 'sparkles shine magic',
      '🌹': 'rose flower love',
      '🇮🇳': 'india flag indian',
    };
    return known[emoji] ?? '';
  }

  Widget buildGifKeyboard(PrivateChatTheme theme) {
    final gifs = ['happy dance', 'anime shock', 'typing fast', 'mission passed', 'bruh moment', 'demon mode', 'cat vibing', 'sus look', 'victory', 'crying laugh', 'mind blown', 'loading...', 'rage quit', 'boss fight', 'nah bro', 'yes sir'];
    final filtered = gifs.where((gif) => gif.toLowerCase().contains(gifSearchText.toLowerCase())).toList();

    return Container(
      height: 330,
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: theme.border)),
      child: Column(children: [
        TextField(
          controller: gifSearchController,
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
          cursorColor: theme.primary,
          onChanged: (value) => setState(() => gifSearchText = value),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: theme.muted),
            hintText: 'Search GIFs',
            hintStyle: TextStyle(color: theme.muted, fontWeight: FontWeight.w700),
            filled: true,
            fillColor: theme.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: theme.primary.withOpacity(0.45))),
          ),
        ),
        SizedBox(height: 10),
        Row(children: [
          Text('Trending GIFs', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
          Spacer(),
          Text('Preview UI', style: TextStyle(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            itemCount: filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.65),
            itemBuilder: (context, index) {
              final gif = filtered[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => sendGif(gif),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.border),
                    gradient: LinearGradient(colors: [theme.primary.withOpacity(theme.isDark ? 0.26 : 0.18), theme.primaryDark.withOpacity(theme.isDark ? 0.16 : 0.12)]),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: Center(child: Icon(Icons.gif_box_rounded, color: Colors.white.withOpacity(0.62), size: 36))),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 700),
                        opacity: 0.85,
                        child: Align(alignment: Alignment.center, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withOpacity(0.72), size: 32)),
                      ),
                    ),
                    Positioned(left: 10, right: 10, bottom: 8, child: Text(gif, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black45, blurRadius: 6)]))),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget buildSearchBar(PrivateChatTheme theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(color: theme.background, border: Border(bottom: BorderSide(color: theme.border))),
      child: Row(children: [
        IconButton(onPressed: () { setState(() { searchMode = false; searchText = ''; searchController.clear(); }); WidgetsBinding.instance.addPostFrameCallback((_) => jumpToBottom()); }, icon: Icon(Icons.arrow_back_rounded, color: theme.text)),
        Expanded(child: TextField(
          controller: searchController,
          autofocus: true,
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
          cursorColor: theme.primary,
          onChanged: (value) => setState(() => searchText = value),
          decoration: InputDecoration(
            hintText: 'Search messages',
            hintStyle: TextStyle(color: theme.muted, fontWeight: FontWeight.w700),
            prefixIcon: Icon(Icons.search_rounded, color: theme.muted),
            filled: true,
            fillColor: theme.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primary.withOpacity(0.45))),
          ),
        )),
      ]),
    );
  }



  Widget buildMessagesBody(List<UiMessage> shownMessages, String query, PrivateChatTheme chatTheme) {
    if (isLoadingMessages) {
      return Center(child: CircularProgressIndicator(color: chatTheme.primary));
    }
    if (messageError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(messageError!, textAlign: TextAlign.center, style: TextStyle(color: chatTheme.muted, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            FilledButton(onPressed: loadMessages, child: Text('Retry')),
          ]),
        ),
      );
    }
    if (shownMessages.isEmpty) {
      return Center(child: Text(searchMode ? 'No matching messages' : 'No messages yet', style: TextStyle(color: chatTheme.muted, fontWeight: FontWeight.w800)));
    }
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: shownMessages.length,
      itemBuilder: (context, index) {
        final displayIndex = shownMessages.length - 1 - index;
        final message = shownMessages[displayIndex];
        final isHit = query.isNotEmpty && (message.text.toLowerCase().contains(query) || message.senderName.toLowerCase().contains(query));
        return Column(children: [
          if (shouldShowDateHeader(shownMessages, displayIndex)) dateHeader(dateLabel(message.createdAt), chatTheme),
          MessageBubble(message: message, showSenderName: widget.chat.isGroup, theme: chatTheme, isPinged: pinnedMessageIds.contains(message.id), isSearchHit: isHit, onReplySwipe: () => startReply(message), onLongPress: () => showMessageActions(message)),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final chatTheme = appThemeController.themeForChat(widget.chat.chatId);
        final bgStyle = appThemeController.backgroundStyleForChat(widget.chat.chatId);
        final shownMessages = visibleMessages;
        final query = searchText.trim().toLowerCase();

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: chatTheme.background,
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              if (searchMode)
                buildSearchBar(chatTheme)
              else
                Container(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                  decoration: BoxDecoration(color: chatTheme.background, border: Border(bottom: BorderSide(color: chatTheme.border))),
                  child: Row(children: [
                    IconButton(onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); Navigator.pop(context); }, icon: Icon(Icons.arrow_back_rounded, color: chatTheme.text)),
                    InkWell(borderRadius: BorderRadius.circular(18), onTap: openSettings, child: Row(children: [ChatAvatar(initials: widget.chat.initials, isGroup: widget.chat.isGroup, isOnline: peerOnline, radius: 22), SizedBox(width: 10)])),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: openSettings,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.chat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: chatTheme.text, fontSize: 17, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text(widget.chat.isGroup ? (typingUsername != null ? '$typingUsername is typing…' : 'Tap for group info') : typingUsername != null ? 'typing…' : peerOnline ? 'Online' : 'Tap for chat info', style: TextStyle(color: (peerOnline || typingUsername != null) ? AppColors.success : chatTheme.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    IconButton(onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => searchMode = true); }, icon: Icon(Icons.search_rounded, color: chatTheme.text)),
                    IconButton(onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); showChatMenu(chatTheme); }, icon: Icon(Icons.more_vert_rounded, color: chatTheme.text)),
                  ]),
                ),
              Expanded(
                child: ChatBackground(
                  theme: chatTheme,
                  styleId: bgStyle,
                  child: buildMessagesBody(shownMessages, query, chatTheme),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: buildComposer(chatTheme),
              ),
            ]),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    socketSubscription?.cancel();
    socketService.dispose();
    messageController.removeListener(_handleTyping);
    messageController.dispose();
    searchController.dispose();
    gifSearchController.dispose();
    emojiSearchController.dispose();
    scrollController.dispose();
    emojiScrollController.dispose();
    messageFocusNode.dispose();
    super.dispose();
  }
}

