import 'package:flutter/material.dart';
import 'package:chattify/utils/theme_controller.dart';

class AppColors {
  static PrivateChatTheme get _theme => appThemeController.currentTheme;

  static Color get background => _theme.background;
  static Color get surface => _theme.surface;
  static Color get primary => _theme.primary;
  static Color get primaryDark => _theme.primaryDark;
  static Color get text => _theme.text;
  static Color get muted => _theme.muted;
  static Color get border => _theme.border;
  static Color get inputFill => _theme.inputFill;
  static bool get isCurrentDark => _theme.isDark;
  static Color get danger => Color(0xFFEF4444);
  static Color get success => Color(0xFF16A34A);
}
