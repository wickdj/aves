import 'dart:math';

import 'package:aves/widgets/editor/transform/handles.dart';
import 'package:aves/widgets/editor/transform/painter.dart';
import 'package:aves/widgets/viewer/visual/state.dart';
import 'package:flutter/material.dart';

class Cropper extends StatefulWidget {
  final ValueNotifier<ViewState> viewStateNotifier;

  static const double handleDimension = kMinInteractiveDimension;

  const Cropper({
    super.key,
    required this.viewStateNotifier,
  });

  @override
  State<Cropper> createState() => _CropperState();
}

class _CropperState extends State<Cropper> {
  late final ValueNotifier<Rect> _outlineNotifier;

  @override
  void initState() {
    super.initState();
    _outlineNotifier = ValueNotifier(const Rect.fromLTWH(0, 50, 100, 200));
  }

  static const double minDimension = Cropper.handleDimension;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<ViewState>(
        valueListenable: widget.viewStateNotifier,
        builder: (context, viewState, child) {
          return ValueListenableBuilder<Rect>(
            valueListenable: _outlineNotifier,
            builder: (context, outline, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: CropperPainter(
                          rect: outline,
                        ),
                      ),
                    ),
                  ),
                  VertexHandle(
                    getPosition: () => outline.topLeft,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.dx),
                      min(outline.bottom - minDimension, v.dy),
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  VertexHandle(
                    getPosition: () => outline.topRight,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      min(outline.bottom - minDimension, v.dy),
                      max(outline.left + minDimension, v.dx),
                      outline.bottom,
                    ),
                  ),
                  VertexHandle(
                    getPosition: () => outline.bottomRight,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      outline.top,
                      max(outline.left + minDimension, v.dx),
                      max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  VertexHandle(
                    getPosition: () => outline.bottomLeft,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.dx),
                      outline.top,
                      outline.right,
                      max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  EdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.topLeft),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.left),
                      outline.top,
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  EdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.topLeft, outline.topRight),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      min(outline.bottom - minDimension, v.top),
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  EdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.bottomRight, outline.topRight),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      outline.top,
                      max(outline.left + minDimension, v.right),
                      outline.bottom,
                    ),
                  ),
                  EdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.bottomRight),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      outline.top,
                      outline.right,
                      max(outline.top + minDimension, v.bottom),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
