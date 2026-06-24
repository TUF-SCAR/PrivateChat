import 'package:flutter/material.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';
import 'package:chattify/widgets/theme_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openThemeScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _AppThemeScreen()));
  }

  void _confirmResetChatThemes(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset all chat themes?'),
        content: Text('Every chat will use the current app theme again. Chat backgrounds will stay the same.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          FilledButton(
            onPressed: () {
              appThemeController.resetAllChatThemesToAppTheme();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All chat themes reset')));
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buttonTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: (danger ? AppColors.danger : AppColors.primary).withOpacity(0.16), child: Icon(icon, color: danger ? AppColors.danger : AppColors.primary)),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: AppColors.text)),
          title: Text('Settings', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              _MeCard(),
              SizedBox(height: 18),
              Text('Look and feel', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              _buttonTile(icon: Icons.palette_rounded, title: 'Theme', subtitle: 'Change the main app theme.', onTap: () => _openThemeScreen(context)),
              _buttonTile(icon: Icons.restart_alt_rounded, title: 'Reset all chat themes', subtitle: 'Make every chat follow ${appThemeController.currentTheme.name}.', onTap: () => _confirmResetChatThemes(context)),
              SizedBox(height: 18),
              Text('Coming later', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              _buttonTile(icon: Icons.notifications_rounded, title: 'Notifications', subtitle: 'Mute style, previews, and sounds later.', onTap: () {}),
              _buttonTile(icon: Icons.lock_rounded, title: 'Privacy', subtitle: 'Online status and read receipts later.', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeCard extends StatefulWidget {
  @override
  State<_MeCard> createState() => _MeCardState();
}

class _MeCardState extends State<_MeCard> {
  CurrentUser? user;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final me = await AuthService.getMe();
      if (mounted) setState(() => user = me);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final username = user?.username ?? 'Loading...';
    final initial = username.isNotEmpty && username != 'Loading...' ? username[0].toUpperCase() : '?';
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: AppColors.primary, child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Me', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text(username, style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text(user == null ? 'Checking login...' : 'User ID: ${user!.id}', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _AppThemeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: AppColors.text)),
          title: Text('Theme', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              Text('Choose app theme', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('Login and register also follow this main theme.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              ThemePicker(),
            ],
          ),
        ),
      ),
    );
  }
}
