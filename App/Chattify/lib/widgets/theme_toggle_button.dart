import 'package:flutter/material.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/utils/theme_controller.dart';
import 'package:chattify/widgets/theme_picker.dart';

class ThemeToggleButton extends StatelessWidget {
  ThemeToggleButton({super.key});

  void openThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedBuilder(
          animation: appThemeController,
          builder: (context, _) {
            return DraggableScrollableSheet(
              initialChildSize: 0.82,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, controller) {
                return Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView(
                    controller: controller,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Choose theme',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '3 light themes and 3 dark themes.',
                        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 18),
                      ThemePicker(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        return Tooltip(
          message: 'Change theme',
          child: IconButton(
            onPressed: () => openThemePicker(context),
            icon: Icon(Icons.palette_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.border),
            ),
          ),
        );
      },
    );
  }
}
