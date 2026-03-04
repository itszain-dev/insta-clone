import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

class StoryRing extends StatefulWidget {
  final String imageUrl;
  final String username;
  final bool viewed;
  final bool isSelf;
  final bool hasStory;
  final VoidCallback onTap;

  const StoryRing({
    super.key,
    required this.imageUrl,
    required this.username,
    required this.viewed,
    required this.onTap,
    this.isSelf = false,
    this.hasStory = false,
  });

  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> {

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 56;
    const double whiteRing = 2;
    const double gradientRing = 3.5;
    final double outerSize = avatarSize + 2 * (whiteRing + gradientRing);

    final gradientColors = const [
      Color(0xFF833AB4), // purple
      Color(0xFFC13584), // magenta
      Color(0xFFE1306C), // pink
      Color(0xFFF56040), // orange
      Color(0xFFFCAF45), // light orange
      Color(0xFFFFDC80), // yellow
      Color(0xFF833AB4), // back to purple to complete sweep
    ];

    final ring = Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (widget.viewed || !widget.hasStory)
            ? null
            : SweepGradient(
                colors: gradientColors,
                stops: const [0.0, 0.15, 0.3, 0.5, 0.7, 0.9, 1.0],
                startAngle: -math.pi / 2,
                endAngle: math.pi * 3 / 2,
              ),
        color: (widget.viewed || !widget.hasStory) ? secondaryColor : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(gradientRing),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
          child: Padding(
            padding: EdgeInsets.all(whiteRing),
            child: CircleAvatar(
              radius: avatarSize / 2,
              backgroundImage: widget.imageUrl.isNotEmpty ? NetworkImage(widget.imageUrl) : null,
              child: widget.imageUrl.isEmpty ? const Icon(Icons.person, color: primaryColor) : null,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ring,
                if (widget.isSelf && !widget.hasStory)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
