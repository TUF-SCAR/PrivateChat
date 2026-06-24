import 'package:flutter/material.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';

class ThemePicker extends StatelessWidget {
  final bool compact;
  final int? chatId;
  final bool centerContent;

  const ThemePicker({
    super.key,
    this.compact = false,
    this.chatId,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final current = chatId == null
            ? appThemeController.currentTheme
            : appThemeController.themeForChat(chatId!);
        final lightThemes = ThemeController.themes.where((theme) => !theme.isDark).toList();
        final darkThemes = ThemeController.themes.where((theme) => theme.isDark).toList();

        return Column(
          crossAxisAlignment: centerContent ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (chatId != null)
              _inheritAppThemeButton(current),
            _sectionTitle('Light themes'),
            ...lightThemes.map((theme) => _themeCard(theme, current.id == theme.id)),
            SizedBox(height: compact ? 10 : 18),
            _sectionTitle('Dark themes'),
            ...darkThemes.map((theme) => _themeCard(theme, current.id == theme.id)),
          ],
        );
      },
    );
  }

  Widget _inheritAppThemeButton(PrivateChatTheme current) {
    final inherited = chatId != null && appThemeController.chatThemeId(chatId!) == null;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => appThemeController.clearChatTheme(chatId!),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: inherited ? AppColors.primary : AppColors.border, width: inherited ? 2 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: current.primary.withOpacity(0.16),
                child: Icon(Icons.phone_android_rounded, color: current.primary),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Use app theme', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Currently ${appThemeController.currentTheme.name}', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (inherited) Icon(Icons.check_circle_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: compact ? 4 : 8),
      child: Text(
        title,
        textAlign: centerContent ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _themeCard(PrivateChatTheme theme, bool selected) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (chatId == null) {
            appThemeController.setTheme(theme);
          } else {
            appThemeController.setChatTheme(chatId!, theme);
          }
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.isCurrentDark ? Color(0xFF111827) : Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(AppColors.isCurrentDark ? 0.18 : 0.06),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.border),
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.text, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          _miniDot(theme.primary),
                          _miniDot(theme.surface),
                          _miniDot(theme.inputFill),
                          SizedBox(width: 8),
                          Text(theme.isDark ? 'Dark' : 'Light', style: TextStyle(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: theme.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}
