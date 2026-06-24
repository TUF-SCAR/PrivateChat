import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:chattify/services/local_store.dart';

class PrivateChatTheme {
  final String id;
  final String name;
  final bool isDark;
  final Color background;
  final Color surface;
  final Color primary;
  final Color primaryDark;
  final Color text;
  final Color muted;
  final Color border;
  final Color inputFill;

  const PrivateChatTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.background,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.text,
    required this.muted,
    required this.border,
    required this.inputFill,
  });
}

class ChatBackgroundStyle {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final bool isAnimated;

  const ChatBackgroundStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.isAnimated = false,
  });
}

class ThemeController extends ChangeNotifier {
  static const List<PrivateChatTheme> themes = [
    PrivateChatTheme(id: 'light_blue', name: 'Sky Light', isDark: false, background: Color(0xFFF4F7FB), surface: Color(0xFFFFFFFF), primary: Color(0xFF2563EB), primaryDark: Color(0xFF1D4ED8), text: Color(0xFF111827), muted: Color(0xFF6B7280), border: Color(0xFFE5E7EB), inputFill: Color(0xFFF3F4F6)),
    PrivateChatTheme(id: 'light_rose', name: 'Rose Light', isDark: false, background: Color(0xFFFFF5F7), surface: Color(0xFFFFFFFF), primary: Color(0xFFE11D48), primaryDark: Color(0xFFBE123C), text: Color(0xFF1F1720), muted: Color(0xFF7A5B66), border: Color(0xFFFFD9E2), inputFill: Color(0xFFFFEEF3)),
    PrivateChatTheme(id: 'light_mint', name: 'Mint Light', isDark: false, background: Color(0xFFF0FDF4), surface: Color(0xFFFFFFFF), primary: Color(0xFF059669), primaryDark: Color(0xFF047857), text: Color(0xFF10231C), muted: Color(0xFF61736B), border: Color(0xFFD1FAE5), inputFill: Color(0xFFEFFBF5)),
    PrivateChatTheme(id: 'light_gold', name: 'Sunlit Gold', isDark: false, background: Color(0xFFFFFBEB), surface: Color(0xFFFFFFFF), primary: Color(0xFFD97706), primaryDark: Color(0xFFB45309), text: Color(0xFF241A0A), muted: Color(0xFF806B43), border: Color(0xFFFDE68A), inputFill: Color(0xFFFFF7D6)),
    PrivateChatTheme(id: 'light_lavender', name: 'Lavender Light', isDark: false, background: Color(0xFFF8F5FF), surface: Color(0xFFFFFFFF), primary: Color(0xFF8B5CF6), primaryDark: Color(0xFF6D28D9), text: Color(0xFF211535), muted: Color(0xFF76658F), border: Color(0xFFE9D5FF), inputFill: Color(0xFFF2EAFF)),
    PrivateChatTheme(id: 'light_ice', name: 'Ice Light', isDark: false, background: Color(0xFFECFEFF), surface: Color(0xFFFFFFFF), primary: Color(0xFF0891B2), primaryDark: Color(0xFF0E7490), text: Color(0xFF0D2530), muted: Color(0xFF5D7380), border: Color(0xFFCFFAFE), inputFill: Color(0xFFE6FBFF)),
    PrivateChatTheme(id: 'dark_blue', name: 'Midnight', isDark: true, background: Color(0xFF0B1220), surface: Color(0xFF111827), primary: Color(0xFF60A5FA), primaryDark: Color(0xFF2563EB), text: Color(0xFFF9FAFB), muted: Color(0xFF9CA3AF), border: Color(0xFF273449), inputFill: Color(0xFF1F2937)),
    PrivateChatTheme(id: 'dark_purple', name: 'Void Purple', isDark: true, background: Color(0xFF120A1F), surface: Color(0xFF1E1233), primary: Color(0xFFA78BFA), primaryDark: Color(0xFF7C3AED), text: Color(0xFFFAF7FF), muted: Color(0xFFB7A6D8), border: Color(0xFF372352), inputFill: Color(0xFF27183F)),
    PrivateChatTheme(id: 'dark_red', name: 'Crimson Dark', isDark: true, background: Color(0xFF16090B), surface: Color(0xFF241012), primary: Color(0xFFFB7185), primaryDark: Color(0xFFBE123C), text: Color(0xFFFFF7F8), muted: Color(0xFFD6A4AD), border: Color(0xFF451A21), inputFill: Color(0xFF331519)),
    PrivateChatTheme(id: 'dark_emerald', name: 'Forest Dark', isDark: true, background: Color(0xFF061713), surface: Color(0xFF0D241D), primary: Color(0xFF34D399), primaryDark: Color(0xFF059669), text: Color(0xFFF0FFF9), muted: Color(0xFF94B8AA), border: Color(0xFF1E4639), inputFill: Color(0xFF123228)),
    PrivateChatTheme(id: 'dark_gold', name: 'Ember Dark', isDark: true, background: Color(0xFF171006), surface: Color(0xFF26190A), primary: Color(0xFFF59E0B), primaryDark: Color(0xFFD97706), text: Color(0xFFFFFBEB), muted: Color(0xFFD1B784), border: Color(0xFF4A3212), inputFill: Color(0xFF332109)),
    PrivateChatTheme(id: 'dark_cyan', name: 'Neon Cyan', isDark: true, background: Color(0xFF06141A), surface: Color(0xFF0C2028), primary: Color(0xFF22D3EE), primaryDark: Color(0xFF0891B2), text: Color(0xFFF0FDFF), muted: Color(0xFF95B8C0), border: Color(0xFF16414D), inputFill: Color(0xFF102C35)),
  ];

  static const List<ChatBackgroundStyle> backgroundStyles = [
    ChatBackgroundStyle(id: 'blank', name: 'Blank', subtitle: 'Plain clean background.', icon: Icons.crop_square_rounded),
    ChatBackgroundStyle(id: 'tech_chat', name: 'Tech chat', subtitle: 'Messages, devices, music, and modern app doodles.', icon: Icons.chat_bubble_rounded),
    ChatBackgroundStyle(id: 'cozy', name: 'Cozy', subtitle: 'Soft room, moon, books, plants, and sleepy doodles.', icon: Icons.local_cafe_rounded),
    ChatBackgroundStyle(id: 'playful', name: 'Playful', subtitle: 'Loose fun shapes, hearts, stars, and happy doodles.', icon: Icons.auto_awesome_rounded),
    ChatBackgroundStyle(id: 'nature', name: 'Nature', subtitle: 'Leaves, flowers, bugs, clouds, and calm outdoor doodles.', icon: Icons.park_rounded),
    ChatBackgroundStyle(id: 'abstract', name: 'Abstract', subtitle: 'Clean minimal symbols, loops, sparkles, and shapes.', icon: Icons.category_rounded),
    ChatBackgroundStyle(id: 'dream_drift', name: 'Dream drift', subtitle: 'Animated slow floating moon, cloud, and dream doodles.', icon: Icons.blur_on_rounded, isAnimated: true),
    ChatBackgroundStyle(id: 'arcade_drift', name: 'Arcade drift', subtitle: 'Animated slow floating arcade and game doodles.', icon: Icons.motion_photos_auto_rounded, isAnimated: true),
  ];
  PrivateChatTheme _currentTheme = themes.firstWhere((theme) => theme.id == 'dark_blue');
  bool _initialThemeApplied = false;
  bool _settingsLoaded = false;

  final Map<int, String> _chatThemeIds = {};
  final Map<int, String> _chatBackgroundStyleIds = {};

  PrivateChatTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _currentTheme.isDark;
  ThemeMode get themeMode => _currentTheme.isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSavedSettings(Brightness brightness) async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;

    final savedThemeId = await LocalStore.getString('app_theme_id');
    if (savedThemeId == null || savedThemeId.isEmpty) {
      applyDeviceDefaultTheme(brightness);
    } else {
      _currentTheme = themes.firstWhere(
        (theme) => theme.id == savedThemeId,
        orElse: () => brightness == Brightness.dark
            ? themes.firstWhere((theme) => theme.id == 'dark_blue')
            : themes.firstWhere((theme) => theme.id == 'light_blue'),
      );
      _initialThemeApplied = true;
    }

    final rawChatThemes = await LocalStore.getString('chat_theme_ids_v1');
    if (rawChatThemes != null && rawChatThemes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawChatThemes);
        if (decoded is Map) {
          _chatThemeIds
            ..clear()
            ..addAll(decoded.map((key, value) => MapEntry(int.parse(key.toString()), value.toString())));
        }
      } catch (_) {}
    }

    final rawBackgrounds = await LocalStore.getString('chat_background_style_ids_v1');
    if (rawBackgrounds != null && rawBackgrounds.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBackgrounds);
        if (decoded is Map) {
          _chatBackgroundStyleIds
            ..clear()
            ..addAll(decoded.map((key, value) => MapEntry(int.parse(key.toString()), value.toString())));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveAppTheme() async {
    await LocalStore.setString('app_theme_id', _currentTheme.id);
  }

  Future<void> _saveChatThemes() async {
    await LocalStore.setString(
      'chat_theme_ids_v1',
      jsonEncode(_chatThemeIds.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  Future<void> _saveChatBackgrounds() async {
    await LocalStore.setString(
      'chat_background_style_ids_v1',
      jsonEncode(_chatBackgroundStyleIds.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  void applyDeviceDefaultTheme(Brightness brightness) {
    if (_initialThemeApplied) return;
    _initialThemeApplied = true;
    _currentTheme = brightness == Brightness.dark
        ? themes.firstWhere((theme) => theme.id == 'dark_blue')
        : themes.firstWhere((theme) => theme.id == 'light_blue');
  }

  void setTheme(PrivateChatTheme theme) {
    _initialThemeApplied = true;
    _currentTheme = theme;
    _saveAppTheme();
    notifyListeners();
  }

  void setThemeById(String id) {
    final theme = themes.firstWhere((item) => item.id == id, orElse: () => themes.first);
    setTheme(theme);
  }

  PrivateChatTheme themeForChat(int chatId) {
    final id = _chatThemeIds[chatId];
    if (id == null) return _currentTheme;
    return themes.firstWhere((theme) => theme.id == id, orElse: () => _currentTheme);
  }

  String? chatThemeId(int chatId) => _chatThemeIds[chatId];

  void setChatTheme(int chatId, PrivateChatTheme theme) {
    _chatThemeIds[chatId] = theme.id;
    _saveChatThemes();
    notifyListeners();
  }

  void clearChatTheme(int chatId) {
    _chatThemeIds.remove(chatId);
    _saveChatThemes();
    notifyListeners();
  }

  void resetAllChatThemesToAppTheme() {
    _chatThemeIds.clear();
    _saveChatThemes();
    notifyListeners();
  }

  String backgroundStyleForChat(int chatId) => _chatBackgroundStyleIds[chatId] ?? 'blank';

  void setChatBackgroundStyle(int chatId, String styleId) {
    _chatBackgroundStyleIds[chatId] = styleId;
    _saveChatBackgrounds();
    notifyListeners();
  }
}

final ThemeController appThemeController = ThemeController();
