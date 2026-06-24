import 'package:flutter/material.dart';
import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/screens/chat_screen.dart';
import 'package:chattify/screens/login_screen.dart';
import 'package:chattify/screens/settings_screen.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/services/chat_service.dart';
import 'package:chattify/services/app_cache_service.dart';
import 'package:chattify/services/group_service.dart';
import 'package:chattify/services/user_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/widgets/chat_tile.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final searchController = TextEditingController();
  final listNameController = TextEditingController();
  final userSearchController = TextEditingController();
  final groupNameController = TextEditingController();

  String selectedFilter = 'All';
  String searchText = '';
  bool isLoading = true;
  String? errorText;
  int? myUserId;
  String? myUsername;

  final Set<int> archivedChatIds = {};
  final Map<String, Set<int>> customLists = {};
  List<UiChat> chats = [];

  List<String> get baseFilters => ['All', 'Unread', 'DMs', 'Groups'];
  List<String> get allFilters => [...baseFilters, ...customLists.keys];

  @override
  void initState() {
    super.initState();
    loadChats();
  }

  Future<void> loadChats() async {
    setState(() {
      isLoading = chats.isEmpty;
      errorText = null;
    });

    final cachedChats = await AppCacheService.loadChats();
    final cachedUserId = await AuthService.currentUserId();
    final cachedUsername = await AuthService.currentUsername();
    if (mounted && cachedChats.isNotEmpty && chats.isEmpty) {
      setState(() {
        myUserId = cachedUserId;
        myUsername = cachedUsername;
        chats = cachedChats;
        isLoading = false;
      });
    }

    try {
      final me = await AuthService.getMe();
      final loadedChats = await ChatService.getAllChats();
      await AppCacheService.saveChats(loadedChats);
      if (!mounted) return;
      setState(() {
        myUserId = me.id;
        myUsername = me.username;
        chats = loadedChats;
        isLoading = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = chats.isEmpty ? error.toString() : null;
        isLoading = false;
      });
    }
  }

  List<UiChat> get filteredChats {
    return chats.where((chat) {
      final archived = archivedChatIds.contains(chat.chatId);
      bool matchesFilter;

      if (selectedFilter == 'Archive') {
        matchesFilter = archived;
      } else if (customLists.containsKey(selectedFilter)) {
        matchesFilter = !archived && customLists[selectedFilter]!.contains(chat.chatId);
      } else {
        matchesFilter = !archived &&
            (selectedFilter == 'All' ||
                (selectedFilter == 'DMs' && !chat.isGroup) ||
                (selectedFilter == 'Groups' && chat.isGroup) ||
                (selectedFilter == 'Unread' && chat.unreadCount > 0));
      }

      final search = searchText.trim().toLowerCase();
      final matchesSearch = search.isEmpty || chat.title.toLowerCase().contains(search) || chat.subtitle.toLowerCase().contains(search);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (_) => false);
  }

  void openNewChatSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.52,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
                SizedBox(height: 22),
                Text('Start something new', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text)),
                SizedBox(height: 14),
                _sheetOption(icon: Icons.person_add_alt_1_rounded, title: 'New private chat', subtitle: 'Search a username and open a DM.', onTap: () { Navigator.pop(context); openPrivateChatSheet(); }),
                _sheetOption(icon: Icons.group_add_rounded, title: 'Create group', subtitle: 'Make a group and add members.', onTap: () { Navigator.pop(context); openCreateGroupSheet(); }),
                _sheetOption(icon: Icons.playlist_add_rounded, title: 'Create chat list', subtitle: 'Make your own list and add chats.', onTap: () { Navigator.pop(context); openCreateListSheet(); }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: EdgeInsets.only(top: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.primary, child: Icon(icon, color: Colors.white)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)), SizedBox(height: 3), Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13))])),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  void openPrivateChatSheet() {
    userSearchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserSearchSheet(
        title: 'New private chat',
        actionText: 'Message',
        onSelected: (user) async {
          Navigator.pop(context);
          try {
            final chatId = await ChatService.createPrivateChat(user.id);
            final chat = await ChatService.openChat(chatId);
            await loadChats();
            if (!mounted) return;
            await Navigator.push(context, PageRouteBuilder(transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero, pageBuilder: (_, __, ___) => ChatScreen(chat: chat, onArchive: () { setState(() { archivedChatIds.add(chat.chatId); selectedFilter = 'All'; }); })));
            loadChats();
          } catch (error) {
            showMessage(error.toString());
          }
        },
      ),
    );
  }

  void openCreateGroupSheet() {
    final selectedUsers = <SearchUser>[];
    groupNameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, sheetSetState) {
          return FractionallySizedBox(
            heightFactor: 0.85,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
                  SizedBox(height: 16),
                  Text('Create group', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 12),
                  TextField(controller: groupNameController, maxLength: 100, decoration: InputDecoration(hintText: 'Group name')),
                  SizedBox(height: 8),
                  if (selectedUsers.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: selectedUsers.map((u) => InputChip(label: Text(u.username), onDeleted: () => sheetSetState(() => selectedUsers.removeWhere((x) => x.id == u.id)))).toList(),
                    ),
                  SizedBox(height: 8),
                  Expanded(
                    child: _EmbeddedUserSearchList(
                      selectedIds: selectedUsers.map((e) => e.id).toSet(),
                      onTap: (user) async {
                        sheetSetState(() {
                          if (!selectedUsers.any((x) => x.id == user.id)) {
                            selectedUsers.add(user);
                          }
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        final name = groupNameController.text.trim();
                        if (name.isEmpty) return showMessage('Enter group name');
                        if (selectedUsers.isEmpty) return showMessage('Select at least one member');
                        try {
                          final chatId = await GroupService.createGroup(name: name, memberIds: selectedUsers.map((e) => e.id).toList());
                          final chat = await ChatService.openChat(chatId);
                          await loadChats();
                          if (!mounted) return;
                          Navigator.pop(context);
                          await Navigator.push(context, PageRouteBuilder(transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero, pageBuilder: (_, __, ___) => ChatScreen(chat: chat, onArchive: () { setState(() { archivedChatIds.add(chat.chatId); selectedFilter = 'All'; }); })));
                          loadChats();
                        } catch (error) {
                          showMessage(error.toString());
                        }
                      },
                      child: Text('Create group'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void openCreateListSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    listNameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
                SizedBox(height: 18),
                Text('Create chat list', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Name limit: 18 characters. Add chats using long press on any chat.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                SizedBox(height: 14),
                TextField(controller: listNameController, maxLength: 18, autofocus: true, decoration: InputDecoration(hintText: 'List name')),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = listNameController.text.trim();
                      if (name.isEmpty || name.length > 18) return;
                      if (customLists.containsKey(name) || baseFilters.contains(name)) return;
                      setState(() {
                        customLists[name] = <int>{};
                        selectedFilter = name;
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Create list'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openChatOptions(UiChat chat) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final archived = archivedChatIds.contains(chat.chatId);
        return StatefulBuilder(builder: (context, sheetSetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 24 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
                SizedBox(height: 14),
                ListTile(
                  leading: Icon(archived ? Icons.unarchive_rounded : Icons.archive_rounded, color: AppColors.text),
                  title: Text(archived ? 'Unarchive chat' : 'Archive chat', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
                  onTap: () {
                    setState(() {
                      if (archived) archivedChatIds.remove(chat.chatId); else archivedChatIds.add(chat.chatId);
                      if (!archived && selectedFilter != 'Archive') selectedFilter = 'All';
                    });
                    Navigator.pop(context);
                  },
                ),
                if (customLists.isNotEmpty) Divider(color: AppColors.border),
                ...customLists.keys.map((name) {
                  final hasChat = customLists[name]!.contains(chat.chatId);
                  return CheckboxListTile(
                    value: hasChat,
                    activeColor: AppColors.primary,
                    title: Text(name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                    subtitle: Text(hasChat ? 'In this list' : 'Add to this list', style: TextStyle(color: AppColors.muted)),
                    onChanged: (_) {
                      sheetSetState(() {});
                      setState(() {
                        if (hasChat) customLists[name]!.remove(chat.chatId); else customLists[name]!.add(chat.chatId);
                      });
                    },
                  );
                }),
              ],
            ),
          );
        });
      },
    );
  }

  Widget filterChip(String label) {
    final active = selectedFilter == label;
    final isCustom = customLists.containsKey(label);
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: isCustom ? Icon(Icons.label_rounded, size: 16, color: active ? Colors.white : AppColors.primary) : null,
        label: Text(label),
        selected: active,
        showCheckmark: false,
        selectedColor: AppColors.primaryDark,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: active ? AppColors.primaryDark : AppColors.border),
        labelStyle: TextStyle(color: active ? Colors.white : AppColors.text, fontWeight: FontWeight.w800),
        onSelected: (_) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => selectedFilter = label); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleChats = filteredChats;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text('PrivateChat', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.text, letterSpacing: -1)),
                  ),
                  IconButton(onPressed: openCreateListSheet, icon: Icon(Icons.playlist_add_rounded), style: IconButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.text, side: BorderSide(color: AppColors.border))),
                  SizedBox(width: 8),
                  IconButton(onPressed: () async { FocusManager.instance.primaryFocus?.unfocus(); await Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); loadChats(); }, icon: Icon(Icons.settings_rounded), style: IconButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.text, side: BorderSide(color: AppColors.border))),
                  SizedBox(width: 8),
                  PopupMenuButton<String>(
                    color: AppColors.surface,
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.text),
                    onSelected: (value) {
                      if (value == 'refresh') loadChats();
                      if (value == 'logout') logout();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'refresh', child: Text('Refresh', style: TextStyle(color: AppColors.text))),
                      PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: AppColors.text))),
                    ],
                  ),
                  SizedBox(width: 8),
                  IconButton.filled(onPressed: openNewChatSheet, icon: Icon(Icons.add_comment_rounded), style: IconButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: searchController,
                onChanged: (value) => setState(() => searchText = value),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: searchText.isEmpty ? null : IconButton(onPressed: () { searchController.clear(); setState(() => searchText = ''); }, icon: Icon(Icons.close_rounded)),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  if (archivedChatIds.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => selectedFilter = selectedFilter == 'Archive' ? 'All' : 'Archive'); },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: selectedFilter == 'Archive' ? AppColors.primaryDark : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: selectedFilter == 'Archive' ? AppColors.primaryDark : AppColors.border)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.archive_rounded, size: 16, color: selectedFilter == 'Archive' ? Colors.white : AppColors.primary), SizedBox(width: 6), Text('Archived', style: TextStyle(color: selectedFilter == 'Archive' ? Colors.white : AppColors.text, fontSize: 12, fontWeight: FontWeight.w900))]),
                        ),
                      ),
                    ),
                  ...allFilters.map(filterChip),
                ],
              ),
            ),
            Expanded(child: _buildChatBody(visibleChats)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(List<UiChat> visibleChats) {
    if (isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (errorText != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(errorText!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
            SizedBox(height: 14),
            FilledButton(onPressed: loadChats, child: Text('Retry')),
          ]),
        ),
      );
    }
    if (visibleChats.isEmpty) return Center(child: Text('No chats found', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)));
    return RefreshIndicator(
      onRefresh: loadChats,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 18 + MediaQuery.of(context).padding.bottom),
        itemCount: visibleChats.length,
        itemBuilder: (context, index) {
          final chat = visibleChats[index];
          return ChatTile(
            chat: chat,
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                    chat: chat,
                    onArchive: () {
                      setState(() {
                        archivedChatIds.add(chat.chatId);
                        selectedFilter = 'All';
                      });
                    },
                  ),
                ),
              );
              loadChats();
            },
            onLongPress: () => openChatOptions(chat),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    listNameController.dispose();
    userSearchController.dispose();
    groupNameController.dispose();
    super.dispose();
  }
}

class _UserSearchSheet extends StatelessWidget {
  final String title;
  final String actionText;
  final Future<void> Function(SearchUser user) onSelected;

  const _UserSearchSheet({required this.title, required this.actionText, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
            SizedBox(height: 16),
            Text(title, style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Expanded(child: _EmbeddedUserSearchList(onTap: onSelected)),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedUserSearchList extends StatefulWidget {
  final Future<void> Function(SearchUser user)? onTap;
  final Set<int> selectedIds;

  const _EmbeddedUserSearchList({this.onTap, this.selectedIds = const {}});

  @override
  State<_EmbeddedUserSearchList> createState() => _EmbeddedUserSearchListState();
}

class _EmbeddedUserSearchListState extends State<_EmbeddedUserSearchList> {
  final controller = TextEditingController();
  List<SearchUser> users = [];
  bool loading = false;
  String? error;

  Future<void> search() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await UserService.searchUsers(q);
      if (!mounted) return;
      setState(() { users = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => search(),
        decoration: InputDecoration(
          hintText: 'Search username',
          prefixIcon: Icon(Icons.search_rounded),
          suffixIcon: IconButton(onPressed: search, icon: Icon(Icons.arrow_forward_rounded)),
        ),
      ),
      SizedBox(height: 10),
      if (loading) LinearProgressIndicator(color: AppColors.primary),
      if (error != null) Padding(padding: EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
      Expanded(
        child: users.isEmpty && !loading
            ? Center(child: Text('Search users to continue', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)))
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final selected = widget.selectedIds.contains(user.id);
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primary, child: Text(user.username[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                    title: Text(user.username, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
                    trailing: selected ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: selected || widget.onTap == null ? null : () => widget.onTap!(user),
                  );
                },
              ),
      ),
    ]);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
