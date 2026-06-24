import 'package:flutter/material.dart';
import 'package:chattify/utils/theme_controller.dart';

class ChatBackground extends StatefulWidget {
  final PrivateChatTheme theme;
  final String styleId;
  final Widget child;

  const ChatBackground({
    super.key,
    required this.theme,
    required this.styleId,
    required this.child,
  });

  @override
  State<ChatBackground> createState() => _ChatBackgroundState();
}

class _ChatBackgroundState extends State<ChatBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  bool get animated =>
      widget.styleId == 'dream_drift' || widget.styleId == 'arcade_drift';

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    if (animated) controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ChatBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (animated && !controller.isAnimating) controller.repeat(reverse: true);
    if (!animated && controller.isAnimating) controller.stop();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String? get assetPath {
    switch (widget.styleId) {
      case 'tech_chat':
        return 'assets/doodles/tech_chat.png';
      case 'cozy':
        return 'assets/doodles/cozy.png';
      case 'playful':
        return 'assets/doodles/playful.png';
      case 'nature':
        return 'assets/doodles/nature.png';
      case 'abstract':
        return 'assets/doodles/abstract.png';
      case 'dream_drift':
        return 'assets/doodles/dream.png';
      case 'arcade_drift':
        return 'assets/doodles/arcade.png';
      default:
        return null;
    }
  }

  Color get doodleColor {
    if (widget.theme.isDark) {
      return Color.alphaBlend(
        widget.theme.primary.withOpacity(0.58),
        widget.theme.primaryDark,
      );
    }
    return Color.alphaBlend(
      widget.theme.primary.withOpacity(0.72),
      widget.theme.primaryDark,
    );
  }

  double get doodleOpacity => widget.theme.isDark ? 0.15 : 0.18;

  @override
  Widget build(BuildContext context) {
    final asset = assetPath;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: widget.theme.background)),
        if (asset != null && !animated)
          Positioned.fill(
            child: _FixedSizeBackground(
              child: _TintedDoodleImage(
                asset: asset,
                color: doodleColor,
                opacity: doodleOpacity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (asset != null && animated)
          Positioned.fill(
            child: _FixedSizeBackground(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                final t = Curves.easeInOut.transform(controller.value);

                // The old animation duplicated the full PNG sheet in layers, so doodles
                // visually stacked on top of each other. This animation keeps ONE sheet
                // only, makes it larger than the screen, and slowly pans it. No overlay.
                final begin = widget.styleId == 'dream_drift'
                    ? const Alignment(-0.42, -0.26)
                    : const Alignment(0.34, -0.30);
                final end = widget.styleId == 'dream_drift'
                    ? const Alignment(0.34, 0.30)
                    : const Alignment(-0.34, 0.26);
                final alignment = Alignment.lerp(begin, end, t)!;
                final scale = widget.styleId == 'dream_drift' ? 1.28 : 1.22;

                  return _SlowPanDoodleImage(
                    asset: asset,
                    color: doodleColor,
                    opacity: doodleOpacity,
                    alignment: alignment,
                    scale: scale,
                  );
                },
              ),
            ),
          ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}


class _FixedSizeBackground extends StatelessWidget {
  final Widget child;

  const _FixedSizeBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ClipRect(
      child: OverflowBox(
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        alignment: Alignment.topCenter,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }
}

class _TintedDoodleImage extends StatelessWidget {
  final String asset;
  final Color color;
  final double opacity;
  final BoxFit fit;
  final Alignment alignment;

  const _TintedDoodleImage({
    required this.asset,
    required this.color,
    required this.opacity,
    required this.fit,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(
          asset,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _SlowPanDoodleImage extends StatelessWidget {
  final String asset;
  final Color color;
  final double opacity;
  final Alignment alignment;
  final double scale;

  const _SlowPanDoodleImage({
    required this.asset,
    required this.color,
    required this.opacity,
    required this.alignment,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: _TintedDoodleImage(
          asset: asset,
          color: color,
          opacity: opacity,
          fit: BoxFit.cover,
          alignment: alignment,
        ),
      ),
    );
  }
}
