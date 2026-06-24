import 'package:flutter/material.dart';
import 'package:chattify/models/ui_chat.dart';
import 'package:chattify/utils/app_colors.dart';
import 'package:chattify/widgets/chat_avatar.dart';

class ChatTile extends StatelessWidget {
  String previewText(String text) {
    final trimmed = text.trim();
    if (trimmed.toUpperCase().startsWith('[GIF:')) return 'gif';
    return text;
  }

  final UiChat chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  ChatTile({super.key, required this.chat, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ChatAvatar(
              initials: chat.initials,
              isGroup: chat.isGroup,
              isOnline: chat.isOnline,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: chat.unreadCount > 0
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      if (chat.lastMessageIsMe) ...[
                        Icon(
                          chat.lastMessageRead
                              ? Icons.done_all_rounded
                              : chat.lastMessageDelivered
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                          size: 16,
                          color: chat.lastMessageRead ? AppColors.primary : AppColors.muted,
                        ),
                        SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          previewText(chat.subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
