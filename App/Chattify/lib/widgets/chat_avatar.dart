import 'package:flutter/material.dart';
import 'package:chattify/utils/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  final String initials;
  final bool isGroup;
  final bool isOnline;
  final double radius;

  ChatAvatar({
    super.key,
    required this.initials,
    required this.isGroup,
    required this.isOnline,
    this.radius = 27,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: isGroup ? AppColors.primary : AppColors.primaryDark,
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (isOnline && !isGroup)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
