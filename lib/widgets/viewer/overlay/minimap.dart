import 'dart:math';

import 'package:aves/utils/vector_utils.dart';
import 'package:aves/widgets/editor/transform/controller.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/model/view_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Minimap extends StatelessWidget {
  final ValueNotifier<ViewState> viewStateNotifier;

  static const Size minimapSize = Size(96, 96);

  const Minimap({
    super.key,
    required this.viewStateNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<ViewState>(
        valueListenable: viewStateNotifier,
        builder: (context, viewState, child) {
          final viewportSize = viewState.viewportSize;
          final contentSize = viewState.contentSize;
          if (viewportSize == null || contentSize == null) return const SizedBox();
          return StreamBuilder<Transformation?>(
              stream: context.select<TransformController?, Stream<Transformation?>>((v) => v?.transformationStream ?? Stream.value(null)),
              builder: (context, snapshot) {
                final transformation = snapshot.data;
                return CustomPaint(
                  painter: MinimapPainter(
                    viewportSize: viewportSize,
                    contentSize: contentSize,
                    viewCenterOffset: viewState.position,
                    viewScale: viewState.scale!,
                    transformation: transformation,
                    minimapBorderColor: Colors.white30,
                  ),
                  size: minimapSize,
                );
              });
        },
      ),
    );
  }
}

class MinimapPainter extends CustomPainter {
  final Size contentSize, viewportSize;
  final Offset viewCenterOffset;
  final double viewScale;
  final Transformation? transformation;
  final Color minimapBorderColor, viewportBorderColor;

  late final Paint fill, minimapStroke, viewportStroke;

  MinimapPainter({
    required this.viewportSize,
    required this.contentSize,
    required this.viewCenterOffset,
    required this.viewScale,
    this.transformation,
    this.minimapBorderColor = Colors.white,
    this.viewportBorderColor = Colors.white,
  }) {
    fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x33000000);
    minimapStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = minimapBorderColor;
    viewportStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = viewportBorderColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (contentSize.width <= 0 || contentSize.height <= 0) return;

    final viewSize = contentSize * viewScale;
    if (viewSize.isEmpty) return;

    // hide minimap when image is in full view
    if (viewportSize + const Offset(precisionErrorTolerance, precisionErrorTolerance) >= viewSize) return;

    final canvasCenter = size.center(Offset.zero);
    final canvasScale = size.longestSide / viewSize.longestSide;
    final scaledContentSize = viewSize * canvasScale;
    final scaledViewportSize = viewportSize * canvasScale;

    final contentRect = Rect.fromCenter(
      center: canvasCenter,
      width: scaledContentSize.width,
      height: scaledContentSize.height,
    );
    final viewportRect = Rect.fromCenter(
      center: canvasCenter - viewCenterOffset * canvasScale,
      width: min(scaledContentSize.width, scaledViewportSize.width),
      height: min(scaledContentSize.height, scaledViewportSize.height),
    );

    Matrix4? transformMatrix;
    if (transformation != null) {
      final viewportCenter = viewportRect.center;
      final transformOrigin = viewportCenter;
      transformMatrix = Matrix4.identity()
        ..translate(transformOrigin.dx, transformOrigin.dy)
        ..multiply(transformation!.matrix)
        ..translate(-transformOrigin.dx, -transformOrigin.dy);
      final transViewportCenter = transformMatrix.transformOffset(viewportCenter);
      final transContentCenter = transformMatrix.transformOffset(contentRect.center);

      final minimapTranslation = size / 2 + (transViewportCenter - transContentCenter - viewportCenter);
      canvas.translate(minimapTranslation.width, minimapTranslation.height);
    } else {
      canvas.translate((contentRect.width - size.width) / 2, (contentRect.height - size.height) / 2);
    }

    canvas.drawRect(viewportRect, fill);

    if (transformMatrix != null) {
      canvas.transform(transformMatrix.storage);
      _drawContentRect(canvas, contentRect);
      transformMatrix.invert();
      canvas.transform(transformMatrix.storage);
    } else {
      _drawContentRect(canvas, contentRect);
    }

    canvas.drawRect(viewportRect, viewportStroke);
  }

  void _drawContentRect(Canvas canvas, Rect contentRect) {
    canvas.drawRect(contentRect, fill);
    canvas.drawRect(contentRect, minimapStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
