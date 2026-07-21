// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A circular progress ring showing an adherence percentage (0.0–1.0),
/// with a large centre label. Colour shifts green → amber → red as the
/// value drops. Animates from 0 to [value] on first build.
class AdherenceRing extends StatelessWidget {
  const AdherenceRing({
    required this.value,
    this.size = 96,
    this.strokeWidth = 9,
    this.centerLabel,
    this.caption,
    this.trackColor,
    super.key,
  });

  final double value;
  final double size;
  final double strokeWidth;

  /// Big text in the middle. Defaults to the rounded percentage.
  final String? centerLabel;

  /// Small text under the percentage (e.g. "today").
  final String? caption;

  final Color? trackColor;

  static Color colorForValue(double value) {
    if (value >= 0.8) return AppColors.pillGreen;
    if (value >= 0.5) return AppColors.warningOrange;
    return AppColors.pillRed;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final ringColor = colorForValue(clamped);
    final label = centerLabel ?? '${(clamped * 100).round()}%';
    final track = trackColor ??
        Theme.of(context).colorScheme.onSurface.withOpacity(0.08);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: ringColor,
            trackColor: track,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w700,
                    color: ringColor,
                    height: 1,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: size * 0.12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * value;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor;
}
