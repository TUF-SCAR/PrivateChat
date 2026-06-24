import 'package:flutter/material.dart';
import 'package:chattify/models/ui_message.dart';
import 'package:chattify/utils/theme_controller.dart';

class MessageBubble extends StatefulWidget {
  final UiMessage message;
  final bool showSenderName;
  final VoidCallback onLongPress;
  final VoidCallback? onReplySwipe;
  final PrivateChatTheme theme;
  final bool isPinged;
  final bool isSearchHit;

  const MessageBubble({
    super.key,
    required this.message,
    required this.showSenderName,
    required this.onLongPress,
    required this.theme,
    this.onReplySwipe,
    this.isPinged = false,
    this.isSearchHit = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  double dragDx = 0;
  late final AnimationController settleController;
  late Animation<double> settleAnimation;

  @override
  void initState() {
    super.initState();
    settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    )..addListener(() {
        setState(() => dragDx = settleAnimation.value);
      });
    settleAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: settleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    settleController.dispose();
    super.dispose();
  }

  String _timeText(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void settleBack() {
    settleController.stop();
    settleAnimation = Tween<double>(begin: dragDx, end: 0).animate(
      CurvedAnimation(parent: settleController, curve: Curves.easeOutCubic),
    );
    settleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final theme = widget.theme;
    final bubbleColor = message.isMe ? theme.primary : theme.surface;
    final textColor = message.isMe ? Colors.white : theme.text;
    final subTextColor = message.isMe ? Colors.white70 : theme.muted;
    final swipeProgress = (dragDx.abs() / 76).clamp(0.0, 1.0);
    final direction = dragDx == 0 ? (message.isMe ? -1.0 : 1.0) : dragDx.sign;

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: Align(
              alignment: direction > 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: Transform.scale(
                scale: 0.65 + (0.35 * swipeProgress),
                child: Opacity(
                  opacity: swipeProgress,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primary.withOpacity(0.32)),
                    ),
                    child: Icon(Icons.reply_rounded, color: theme.primary, size: 20),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dragDx, 0),
            child: GestureDetector(
              onLongPress: widget.onLongPress,
              onHorizontalDragUpdate: (details) {
                final next = dragDx + details.delta.dx;
                setState(() => dragDx = next.clamp(-82.0, 82.0));
              },
              onHorizontalDragEnd: (_) {
                if (dragDx.abs() > 52) widget.onReplySwipe?.call();
                settleBack();
              },
              onHorizontalDragCancel: settleBack,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.fromLTRB(12, 9, 12, 7),
                decoration: BoxDecoration(
                  color: widget.isSearchHit && !message.isMe ? theme.inputFill : bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18 + (swipeProgress * 2)),
                    topRight: Radius.circular(18 + (swipeProgress * 2)),
                    bottomLeft: Radius.circular(message.isMe ? 18 : 5),
                    bottomRight: Radius.circular(message.isMe ? 5 : 18),
                  ),
                  border: Border.all(
                    color: widget.isPinged
                        ? Colors.amber
                        : widget.isSearchHit
                            ? theme.primary
                            : message.isMe
                                ? theme.primary
                                : theme.border,
                    width: (widget.isPinged || widget.isSearchHit) ? 1.8 : 1,
                  ),
                  boxShadow: [
                    if (widget.isPinged)
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.16),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    if (swipeProgress > 0)
                      BoxShadow(
                        color: theme.primary.withOpacity(0.08 * swipeProgress),
                        blurRadius: 12 * swipeProgress,
                        offset: Offset(0, 4 * swipeProgress),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (widget.showSenderName && !message.isMe) ...[
                      Text(message.senderName, style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                    ],
                    if (widget.isPinged) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_rounded, size: 13, color: message.isMe ? Colors.white : Colors.amber.shade700),
                          SizedBox(width: 4),
                          Text('Pinned', style: TextStyle(color: message.isMe ? Colors.white : Colors.amber.shade700, fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      SizedBox(height: 5),
                    ],
                    if (message.replyTo != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.only(bottom: 7),
                        decoration: BoxDecoration(
                          color: message.isMe ? Colors.white.withOpacity(0.16) : theme.inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: message.isMe ? Colors.white : theme.primary, width: 3)),
                        ),
                        child: Text(message.replyTo!.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subTextColor, fontSize: 12)),
                      ),
                    ],
                    Text(
                      message.isDeleted ? 'this message was deleted' : message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                        height: 1.25,
                        fontWeight: widget.isSearchHit ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isEdited && !message.isDeleted) ...[
                          Text('edited', style: TextStyle(fontSize: 11, color: subTextColor)),
                          SizedBox(width: 5),
                        ],
                        Text(_timeText(message.createdAt), style: TextStyle(fontSize: 11, color: subTextColor)),
                        if (message.isMe) ...[
                          SizedBox(width: 4),
                          Icon(message.isRead ? Icons.done_all : Icons.done, size: 15, color: subTextColor),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
