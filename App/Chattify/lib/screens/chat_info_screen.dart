import 'package:flutter/material.dart';
import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/models/ui_member.dart';
import 'package:chattify/screens/chat_screen.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/services/chat_service.dart';
import 'package:chattify/services/group_service.dart';
import 'package:chattify/services/user_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';
import 'package:chattify/widgets/chat_avatar.dart';
import 'package:chattify/widgets/theme_picker.dart';

class ChatInfoScreen extends StatefulWidget {
  final UiChat chat;
  final VoidCallback? onArchive;

  const ChatInfoScreen({super.key, required this.chat, this.onArchive});

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  List<UiMember> members = [];
  bool loadingMembers = false;
  String? membersError;
  int? currentUserId;

  UiChat get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
    if (chat.isGroup) loadMembers();
  }

  Future<void> loadCurrentUser() async {
    currentUserId = await AuthService.currentUserId();
    currentUserId ??= (await AuthService.getMe()).id;
    if (mounted) setState(() {});
  }

  Future<void> loadMembers() async {
    if (!chat.isGroup) return;
    setState(() {
      loadingMembers = true;
      membersError = null;
    });
    try {
      final loaded = await GroupService.getMembers(chat.chatId);
      if (!mounted) return;
      setState(() {
        members = loaded;
        loadingMembers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        membersError = error.toString();
        loadingMembers = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _button(
    PrivateChatTheme theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.danger : theme.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.border)),
        child: Row(children: [
          CircleAvatar(backgroundColor: (danger ? AppColors.danger : theme.primary).withOpacity(0.16), child: Icon(icon, color: danger ? AppColors.danger : theme.primary)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text(subtitle, style: TextStyle(color: theme.muted, fontSize: 13, fontWeight: FontWeight.w600))])),
          Icon(Icons.chevron_right_rounded, color: theme.muted),
        ]),
      ),
    );
  }

  Widget _memberTile(BuildContext context, UiMember member, PrivateChatTheme theme) {
    final isAdmin = member.role == 'admin';
    final isMe = currentUserId == member.userId;
    return InkWell(
      onLongPress: isMe ? null : () => _openMemberActions(context, member, theme),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.border)),
        child: Row(children: [
          ChatAvatar(initials: member.initials, isGroup: false, isOnline: member.isOnline, radius: 22),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? 'You' : member.username, style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text(member.isOnline ? 'Online' : 'Offline', style: TextStyle(color: member.isOnline ? AppColors.success : theme.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: isAdmin ? theme.primary.withOpacity(0.16) : theme.inputFill, borderRadius: BorderRadius.circular(999)),
            child: Text(member.role, style: TextStyle(color: isAdmin ? theme.primary : theme.muted, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }

  void _openMemberActions(BuildContext context, UiMember member, PrivateChatTheme theme) {
    final isAdmin = member.role == 'admin';
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.62,
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 24 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))),
                SizedBox(height: 16),
                Row(children: [
                  ChatAvatar(initials: member.initials, isGroup: false, isOnline: member.isOnline, radius: 24),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(member.username, style: TextStyle(color: theme.text, fontSize: 20, fontWeight: FontWeight.w900)), Text(member.role, style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700))])),
                ]),
                SizedBox(height: 14),
                _memberActionTile(context, theme, icon: Icons.chat_bubble_rounded, title: 'Message', subtitle: 'Open or create a private DM.', onTap: () async {
                  Navigator.pop(context);
                  try {
                    final chatId = await ChatService.createPrivateChat(member.userId);
                    final dm = await ChatService.openChat(chatId);
                    if (!mounted) return;
                    Navigator.push(context, PageRouteBuilder(transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero, pageBuilder: (_, __, ___) => ChatScreen(chat: dm)));
                  } catch (error) {
                    showMessage(error.toString());
                  }
                }),
                _memberActionTile(context, theme, icon: Icons.admin_panel_settings_rounded, title: isAdmin ? 'Remove admin' : 'Make admin', subtitle: 'Toggle group admin role.', onTap: () async {
                  Navigator.pop(context);
                  try {
                    await GroupService.changeRole(chatId: chat.chatId, userId: member.userId, role: isAdmin ? 'member' : 'admin');
                    await loadMembers();
                  } catch (error) {
                    showMessage(error.toString());
                  }
                }),
                _memberActionTile(context, theme, icon: Icons.person_remove_alt_1_rounded, title: 'Remove from group', subtitle: 'Ask before removing this member.', danger: true, onTap: () {
                  Navigator.pop(context);
                  _confirmRemoveMember(context, member, theme);
                }),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _memberActionTile(BuildContext context, PrivateChatTheme theme, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : theme.primary),
      title: Text(title, style: TextStyle(color: danger ? AppColors.danger : theme.text, fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.muted, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  void _confirmRemoveMember(BuildContext context, UiMember member, PrivateChatTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Remove ${member.username}?', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
        content: Text('Do you really want to remove this person from the group?', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await GroupService.removeMember(chatId: chat.chatId, userId: member.userId);
                await loadMembers();
              } catch (error) {
                showMessage(error.toString());
              }
            },
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openAddPeopleSheet(PrivateChatTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))),
            SizedBox(height: 16),
            Text('Add people', style: TextStyle(color: theme.text, fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Expanded(child: _AddPeopleSearch(theme: theme, existingIds: members.map((e) => e.userId).toSet(), onAdd: (user) async {
              try {
                await GroupService.addMember(chatId: chat.chatId, userId: user.id);
                await loadMembers();
                if (mounted) showMessage('${user.username} added');
              } catch (error) {
                showMessage(error.toString());
              }
            })),
          ]),
        ),
      ),
    );
  }

  void _openThemeScreen(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatThemeScreen(chat: chat)));
  void _openBackgroundScreen(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatBackgroundScreen(chat: chat)));

  void _archiveAndBack(BuildContext context) {
    widget.onArchive?.call();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _deleteOrLeave({required bool deleteGroup}) async {
    try {
      if (chat.isGroup) {
        if (deleteGroup) {
          await GroupService.deleteGroup(chat.chatId);
        } else {
          await GroupService.leaveGroup(chat.chatId);
        }
      } else {
        await ChatService.deletePrivateChat(chat.chatId);
      }
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      showMessage(error.toString());
    }
  }

  Widget _membersSection(PrivateChatTheme theme) {
    if (loadingMembers) return Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: theme.primary)));
    if (membersError != null) return Column(children: [Text(membersError!, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)), SizedBox(height: 8), FilledButton(onPressed: loadMembers, child: Text('Retry'))]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('Members', style: TextStyle(color: theme.text, fontSize: 21, fontWeight: FontWeight.w900))), Text('${members.length}', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w900))]),
      SizedBox(height: 12),
      ...members.map((member) => _memberTile(context, member, theme)),
      SizedBox(height: 6),
      _button(theme, icon: Icons.person_add_alt_1_rounded, title: 'Add people', subtitle: 'Add new members to this group.', onTap: () => _openAddPeopleSheet(theme)),
      SizedBox(height: 10),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final theme = appThemeController.themeForChat(chat.chatId);
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: theme.text)),
            title: Text(chat.isGroup ? 'Group settings' : 'Chat settings', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Center(child: Column(children: [
                  ChatAvatar(initials: chat.initials, isGroup: chat.isGroup, isOnline: chat.isOnline, radius: 44),
                  SizedBox(height: 12),
                  Text(chat.title, textAlign: TextAlign.center, style: TextStyle(color: theme.text, fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text(chat.isGroup ? '${members.length} members' : (chat.isOnline ? 'Online' : 'Private chat'), style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
                ])),
                SizedBox(height: 26),
                if (chat.isGroup) _membersSection(theme),
                Text('Appearance', style: TextStyle(color: theme.text, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                _button(theme, icon: Icons.palette_rounded, title: 'Chat theme', subtitle: 'Theme only for this chat.', onTap: () => _openThemeScreen(context)),
                _button(theme, icon: Icons.wallpaper_rounded, title: 'Chat background', subtitle: 'Blank, static, or animated backgrounds.', onTap: () => _openBackgroundScreen(context)),
                SizedBox(height: 10),
                Text('Chat actions', style: TextStyle(color: theme.text, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                _button(theme, icon: Icons.archive_rounded, title: 'Archive chat', subtitle: 'Hide from normal chat list.', onTap: () => _archiveAndBack(context)),
                SizedBox(height: 10),
                Text('Danger zone', style: TextStyle(color: theme.text, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                if (chat.isGroup) ...[
                  _button(theme, icon: Icons.logout_rounded, title: 'Leave group', subtitle: 'Leave this group.', onTap: () => _deleteOrLeave(deleteGroup: false), danger: true),
                  _button(theme, icon: Icons.delete_forever_rounded, title: 'Delete group', subtitle: 'Admin only.', onTap: () => _deleteOrLeave(deleteGroup: true), danger: true),
                ] else
                  _button(theme, icon: Icons.delete_outline_rounded, title: 'Delete chat for me', subtitle: 'Hide this private chat.', onTap: () => _deleteOrLeave(deleteGroup: false), danger: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddPeopleSearch extends StatefulWidget {
  final PrivateChatTheme theme;
  final Set<int> existingIds;
  final Future<void> Function(SearchUser user) onAdd;

  const _AddPeopleSearch({required this.theme, required this.existingIds, required this.onAdd});

  @override
  State<_AddPeopleSearch> createState() => _AddPeopleSearchState();
}

class _AddPeopleSearchState extends State<_AddPeopleSearch> {
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
    final theme = widget.theme;
    return Column(children: [
      TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.search, onSubmitted: (_) => search(), decoration: InputDecoration(hintText: 'Search username', prefixIcon: Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: search, icon: Icon(Icons.arrow_forward_rounded)))),
      SizedBox(height: 10),
      if (loading) LinearProgressIndicator(color: theme.primary),
      if (error != null) Padding(padding: EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
      Expanded(
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final exists = widget.existingIds.contains(user.id);
            return ListTile(
              title: Text(user.username, style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
              subtitle: Text(exists ? 'Already in group' : 'Tap to add', style: TextStyle(color: theme.muted)),
              trailing: exists ? Icon(Icons.check_circle_rounded, color: theme.primary) : Icon(Icons.add_rounded, color: theme.primary),
              onTap: exists ? null : () => widget.onAdd(user),
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

class _ChatThemeScreen extends StatelessWidget {
  final UiChat chat;
  const _ChatThemeScreen({required this.chat});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final theme = appThemeController.themeForChat(chat.chatId);
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: theme.text)),
            title: Text('Chat theme', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Text('Theme for ${chat.title}', style: TextStyle(color: theme.text, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('This changes the header, messages, composer, settings, and background colours for this chat.', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
                SizedBox(height: 16),
                ThemePicker(chatId: chat.chatId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatBackgroundScreen extends StatelessWidget {
  final UiChat chat;
  const _ChatBackgroundScreen({required this.chat});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final theme = appThemeController.themeForChat(chat.chatId);
        final selectedId = appThemeController.backgroundStyleForChat(chat.chatId);
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: theme.text)),
            title: Text('Chat background', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Text('Background for ${chat.title}', style: TextStyle(color: theme.text, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Animated options now pan a single doodle sheet, so doodles do not stack over each other.', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
                SizedBox(height: 16),
                ...ThemeController.backgroundStyles.map((style) {
                  final selected = selectedId == style.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => appThemeController.setChatBackgroundStyle(chat.chatId, style.id),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? theme.primary : theme.border, width: selected ? 2 : 1),
                      ),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: theme.primary.withOpacity(0.16), child: Icon(style.icon, color: theme.primary)),
                        SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(style.name, style: TextStyle(color: theme.text, fontWeight: FontWeight.w900))),
                            if (style.isAnimated) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: theme.primary.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
                                child: Text('Animated', style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ]),
                          SizedBox(height: 3),
                          Text(style.subtitle, style: TextStyle(color: theme.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                        ])),
                        if (selected) Icon(Icons.check_circle_rounded, color: theme.primary),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
