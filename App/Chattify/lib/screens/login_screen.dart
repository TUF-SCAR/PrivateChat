import 'package:flutter/material.dart';
import 'package:chattify/screens/chat_list_screen.dart';
import 'package:chattify/screens/register_screen.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/widgets/theme_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailOrUsernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordObscured = true;
  bool isLoading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> login() async {
    final emailOrUsername = emailOrUsernameController.text.trim();
    final password = passwordController.text;

    if (emailOrUsername.isEmpty) {
      showMessage('Enter email or username');
      return;
    }
    if (password.isEmpty) {
      showMessage('Enter password');
      return;
    }
    if (password.length < 8) {
      showMessage('Password must be at least 8 characters long');
      return;
    }

    setState(() => isLoading = true);
    try {
      await AuthService.login(emailOrUsername: emailOrUsername, password: password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatListScreen()),
      );
    } catch (error) {
      if (mounted) showMessage(error.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.centerRight, child: ThemeToggleButton()),
              SizedBox(height: 20),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.lock_person_rounded, color: Colors.white, size: 30),
              ),
              SizedBox(height: 24),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  letterSpacing: -1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Login to continue your private conversations.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: emailOrUsernameController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email or username',
                        hintText: 'scar or scar@example.com',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      textInputAction: TextInputAction.done,
                      obscureText: isPasswordObscured,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => isPasswordObscured = !isPasswordObscured);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primaryDark.withOpacity(0.7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : Text(
                                'Login',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterScreen()),
                    );
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailOrUsernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
