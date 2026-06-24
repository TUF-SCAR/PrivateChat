import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chattify/screens/login_screen.dart';
import 'package:chattify/screens/chat_list_screen.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  await appThemeController.loadSavedSettings(brightness);
  runApp(PrivateChatApp());
}

class PrivateChatApp extends StatelessWidget {
  PrivateChatApp({super.key});

  ThemeData buildTheme({required bool isDark}) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900),
        contentTextStyle: TextStyle(color: AppColors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        labelStyle: TextStyle(color: AppColors.muted),
        hintStyle: TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  void setSystemBars(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final isDark = appThemeController.isDarkMode;
        setSystemBars(isDark);

        return MaterialApp(
          title: 'PrivateChat',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(isDark: false),
          darkTheme: buildTheme(isDark: true),
          themeMode: appThemeController.themeMode,
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? SizedBox.shrink(),
            );
          },
          home: AuthGate(),
        );
      },
    );
  }
}


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _loggedIn = _checkLogin();

  Future<bool> _checkLogin() async {
    final token = await AuthService.token();
    if (token == null || token.isEmpty) return false;
    try {
      await AuthService.getMe();
      return true;
    } catch (_) {
      await AuthService.logout();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedIn,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        return snapshot.data == true ? ChatListScreen() : LoginScreen();
      },
    );
  }
}
