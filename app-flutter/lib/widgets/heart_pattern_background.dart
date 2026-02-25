import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A matte background with small hearts in different sizes and orientations.
/// Used as the app-wide background behind all pages.
class HeartPatternBackground extends StatelessWidget {
  const HeartPatternBackground({super.key});

  static const Color _matteColor = Color(0xFFF8F4F8);
  static const Color _heartColor = Color.fromARGB(13, 105, 105, 105); // very subtle dark

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const sizes = [14.0, 16.0, 18.0, 20.0, 22.0, 24.0];
        final rng = math.Random(42);
        final children = <Widget>[];
        // Approximate count for good coverage with uneven spacing
        final count = (w * h / 1800).round().clamp(80, 400);

        for (int i = 0; i < count; i++) {
          final size = sizes[rng.nextInt(sizes.length)];
          final rotation = (rng.nextDouble() - 0.5) * 0.8;
          final x = rng.nextDouble() * (w + size * 2) - size;
          final y = rng.nextDouble() * (h + size * 2) - size;
          children.add(
            Positioned(
              left: x,
              top: y,
              child: Transform.rotate(
                angle: rotation,
                child: Icon(
                  Icons.favorite,
                  size: size,
                  color: _heartColor,
                ),
              ),
            ),
          );
        }

        return Container(
          width: w,
          height: h,
          color: _matteColor,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }
}
