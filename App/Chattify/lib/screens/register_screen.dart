import 'package:flutter/material.dart';
import 'package:chattify/services/auth_service.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/widgets/theme_toggle_button.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isPasswordObscured = true;
  bool isConfirmPasswordObscured = true;
  bool isLoading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> register() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (username.isEmpty) {
      showMessage('Enter username');
      return;
    }
    if (username.length < 3) {
      showMessage('Username must be at least 3 characters');
      return;
    }
    if (email.isEmpty) {
      showMessage('Enter email');
      return;
    }
    if (!email.contains('@')) {
      showMessage('Enter a valid email');
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
    if (confirmPassword.isEmpty) {
      showMessage('Confirm your password');
      return;
    }
    if (confirmPassword != password) {
      showMessage('Passwords do not match');
      return;
    }

    setState(() => isLoading = true);
    try {
      await AuthService.register(username: username, email: email, password: password);
      if (!mounted) return;
      showMessage('Account created successfully');
      Navigator.pop(context);
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
              SizedBox(height: 18),
              Row(
                children: [
                  IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.text,
                    ),
                  ),
                  Spacer(),
                  ThemeToggleButton(),
                ],
              ),
              SizedBox(height: 22),
              Text(
                'Create account',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  letterSpacing: -1.1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Join PrivateChat and start messaging safely.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Choose a username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      textInputAction: TextInputAction.next,
                      obscureText: isPasswordObscured,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
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
                    SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      textInputAction: TextInputAction.done,
                      obscureText: isConfirmPasswordObscured,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => register(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        hintText: 'Enter password again',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isConfirmPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => isConfirmPasswordObscured = !isConfirmPasswordObscured);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : register,
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
                                'Register',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
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
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
