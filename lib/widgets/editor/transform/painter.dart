import 'package:flutter/material.dart';

class CropperPainter extends CustomPainter {
  final Rect rect;

  const CropperPainter({
    required this.rect,
  });

  static const double cornerRadius = 6;
  static const double borderWidth = 2;
  static const double gridWidth = 1;
  static const int gridCount = 3;

  static final scrimColor = Colors.black.withOpacity(.5);
  static const cornerColor = Colors.white;
  static final borderColor = Colors.white.withOpacity(.5);
  static final gridColor = Colors.white.withOpacity(.5);

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scrimColor;
    final cornerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = cornerColor;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = borderColor;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = gridWidth
      ..color = gridColor;

    final outside = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..close();
    final inside = Path()
      ..addRect(rect.inflate(borderWidth / 2))
      ..close();
    canvas.drawPath(Path.combine(PathOperation.difference, outside, inside), scrimPaint);

    canvas.drawRect(rect, borderPaint);

    final xLeft = rect.left;
    final yTop = rect.top;
    final xRight = rect.right;
    final yBottom = rect.bottom;

    final gridLeft = xLeft + borderWidth / 2;
    final gridRight = xRight - borderWidth / 2;
    final yStep = (yBottom - yTop) / gridCount;
    for (var i = 1; i < gridCount; i++) {
      canvas.drawLine(
        Offset(gridLeft, yTop + i * yStep),
        Offset(gridRight, yTop + i * yStep),
        gridPaint,
      );
    }
    final gridTop = yTop + borderWidth / 2;
    final gridBottom = yBottom - borderWidth / 2;
    final xStep = (xRight - xLeft) / gridCount;
    for (var i = 1; i < gridCount; i++) {
      canvas.drawLine(
        Offset(xLeft + i * xStep, gridTop),
        Offset(xLeft + i * xStep, gridBottom),
        gridPaint,
      );
    }

    canvas.drawCircle(rect.topLeft, cornerRadius, cornerPaint);
    canvas.drawCircle(rect.topRight, cornerRadius, cornerPaint);
    canvas.drawCircle(rect.bottomLeft, cornerRadius, cornerPaint);
    canvas.drawCircle(rect.bottomRight, cornerRadius, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
