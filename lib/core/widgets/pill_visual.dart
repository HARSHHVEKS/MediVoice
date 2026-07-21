// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// A reusable medicine visual: shows the pill photo if one exists,
/// otherwise draws a gently floating shape tinted by the pill colour.
///
/// Extracted from the previously-duplicated widgets in the patient home
/// and caregiver medication-list screens.
class PillVisual extends StatelessWidget {
  const PillVisual({
    required this.shape,
    required this.colorName,
    this.photoPath,
    this.size = 64,
    this.animate = true,
    super.key,
  });

  final String? shape;
  final String? colorName;
  final String? photoPath;
  final double size;
  final bool animate;

  static Color colorFor(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'red':
        return AppColors.pillRed;
      case 'blue':
        return AppColors.pillBlue;
      case 'green':
        return AppColors.pillGreen;
      case 'yellow':
        return AppColors.pillYellow;
      case 'orange':
        return AppColors.pillOrange;
      case 'purple':
        return AppColors.pillPurple;
      case 'pink':
        return AppColors.pillPink;
      case 'white':
        return AppColors.pillWhite;
      case 'brown':
        return AppColors.pillBrown;
      default:
        return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      if (file.existsSync()) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }
    return _AnimatedPill(
      shape: shape ?? 'tablet',
      color: colorFor(colorName),
      size: size,
      animate: animate,
    );
  }
}

class _AnimatedPill extends StatefulWidget {
  const _AnimatedPill({
    required this.shape,
    required this.color,
    required this.size,
    required this.animate,
  });

  final String shape;
  final Color color;
  final double size;
  final bool animate;

  @override
  State<_AnimatedPill> createState() => _AnimatedPillState();
}

class _AnimatedPillState extends State<_AnimatedPill>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _float;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat(reverse: true);
      _float = Tween<double>(begin: -3, end: 3).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: widget.color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Center(child: _buildShape()),
    );

    if (!widget.animate || _float == null) return tile;

    return AnimatedBuilder(
      animation: _float!,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _float!.value),
        child: child,
      ),
      child: tile,
    );
  }

  Widget _buildShape() {
    switch (widget.shape.toLowerCase()) {
      case 'capsule':
        return _capsule();
      case 'syrup':
      case 'liquid':
        return _bottle();
      case 'drops':
        return _drop();
      case 'inhaler':
        return _inhaler();
      case 'injection':
        return _injection();
      case 'patch':
        return _patch();
      case 'tablet':
      default:
        return _tablet();
    }
  }

  Widget _tablet() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 26,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _capsule() => Container(
        width: 44,
        height: 21,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(child: Container(color: widget.color)),
            Expanded(
              child: Container(color: widget.color.withOpacity(0.45)),
            ),
          ],
        ),
      );

  Widget _bottle() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _drop() => CustomPaint(
        size: const Size(30, 42),
        painter: _DropPainter(color: widget.color),
      );

  Widget _inhaler() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 7,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 26,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _injection() => Transform.rotate(
        angle: -0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 30,
              height: 13,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.25),
                border: Border.all(color: widget.color, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 15,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );

  Widget _patch() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: widget.color, width: 2.5),
        ),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

class _DropPainter extends CustomPainter {
  _DropPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(
          size.width, size.height * 0.5, size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.5, size.width / 2, 0);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.3),
      4,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.color != color;
}
