import 'dart:async';
import 'dart:math';

import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/editor/transform/handles.dart';
import 'package:aves/widgets/editor/transform/painter.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/widgets/viewer/visual/state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Cropper extends StatefulWidget {
  final TransformController controller;
  final ValueNotifier<ViewState> viewStateNotifier;

  static const double handleDimension = kMinInteractiveDimension;

  const Cropper({
    super.key,
    required this.controller,
    required this.viewStateNotifier,
  });

  @override
  State<Cropper> createState() => _CropperState();
}

class _CropperState extends State<Cropper> with SingleTickerProviderStateMixin {
  final List<StreamSubscription> _subscriptions = [];
  final ValueNotifier<int> _gridDivisionNotifier = ValueNotifier(0);
  late final ValueNotifier<Rect> _outlineNotifier;
  late AnimationController _gridAnimationController;
  late Animation<double> _gridOpacity;

  static const double minDimension = Cropper.handleDimension;
  static const int resizeGridDivision = 3;
  static const int straightenGridDivision = 9;

  TransformController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _outlineNotifier = ValueNotifier(const Rect.fromLTWH(0, 50, 100, 200));
    _gridAnimationController = AnimationController(
      duration: context.read<DurationsData>().viewerOverlayAnimation,
      vsync: this,
    );
    _gridOpacity = CurvedAnimation(
      parent: _gridAnimationController,
      curve: Curves.easeOutQuad,
    );
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant Cropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _gridDivisionNotifier.dispose();
    _outlineNotifier.dispose();
    _gridAnimationController.dispose();
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(Cropper widget) {
    _subscriptions.add(widget.controller.eventStream.listen(_onTransformEvent));
  }

  void _unregisterWidget(Cropper widget) {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

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
                      child: ValueListenableBuilder<int>(
                        valueListenable: _gridDivisionNotifier,
                        builder: (context, gridDivision, child) {
                          return ValueListenableBuilder<double>(
                            valueListenable: _gridOpacity,
                            builder: (context, gridOpacity, child) {
                              return CustomPaint(
                                painter: CropperPainter(
                                  rect: outline,
                                  gridOpacity: gridOpacity,
                                  gridDivision: gridDivision,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  _buildVertexHandle(
                    getPosition: () => outline.topLeft,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.dx),
                      min(outline.bottom - minDimension, v.dy),
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  _buildVertexHandle(
                    getPosition: () => outline.topRight,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      min(outline.bottom - minDimension, v.dy),
                      max(outline.left + minDimension, v.dx),
                      outline.bottom,
                    ),
                  ),
                  _buildVertexHandle(
                    getPosition: () => outline.bottomRight,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      outline.top,
                      max(outline.left + minDimension, v.dx),
                      max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  _buildVertexHandle(
                    getPosition: () => outline.bottomLeft,
                    setPosition: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.dx),
                      outline.top,
                      outline.right,
                      max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  _buildEdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.topLeft),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      min(outline.right - minDimension, v.left),
                      outline.top,
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  _buildEdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.topLeft, outline.topRight),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      min(outline.bottom - minDimension, v.top),
                      outline.right,
                      outline.bottom,
                    ),
                  ),
                  _buildEdgeHandle(
                    getEdge: () => Rect.fromPoints(outline.bottomRight, outline.topRight),
                    setEdge: (v) => _outlineNotifier.value = Rect.fromLTRB(
                      outline.left,
                      outline.top,
                      max(outline.left + minDimension, v.right),
                      outline.bottom,
                    ),
                  ),
                  _buildEdgeHandle(
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

  VertexHandle _buildVertexHandle({
    required ValueGetter<Offset> getPosition,
    required ValueSetter<Offset> setPosition,
  }) {
    return VertexHandle(
      getPosition: getPosition,
      setPosition: setPosition,
      onDragStart: _onDragStart,
      onDragEnd: _onDragEnd,
    );
  }

  EdgeHandle _buildEdgeHandle({
    required ValueGetter<Rect> getEdge,
    required ValueSetter<Rect> setEdge,
  }) {
    return EdgeHandle(
      getEdge: getEdge,
      setEdge: setEdge,
      onDragStart: _onDragStart,
      onDragEnd: _onDragEnd,
    );
  }

  void _onDragStart() => controller.activity = TransformActivity.resize;

  void _onDragEnd() => controller.activity = TransformActivity.none;

  void _onTransformEvent(TransformEvent event) {
    final activity = event.activity;
    switch (activity) {
      case TransformActivity.none:
        break;
      case TransformActivity.resize:
        _gridDivisionNotifier.value = resizeGridDivision;
        break;
      case TransformActivity.straighten:
        _gridDivisionNotifier.value = straightenGridDivision;
        break;
    }
    if (activity == TransformActivity.none) {
      _gridAnimationController.reverse();
    } else {
      _gridAnimationController.forward();
    }
  }
}
