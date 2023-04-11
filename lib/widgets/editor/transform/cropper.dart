import 'dart:async';
import 'dart:math';

import 'package:aves/model/view_state.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/common/fx/dashed_path_painter.dart';
import 'package:aves/widgets/editor/transform/controller.dart';
import 'package:aves/widgets/editor/transform/crop_region.dart';
import 'package:aves/widgets/editor/transform/handles.dart';
import 'package:aves/widgets/editor/transform/painter.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves_magnifier/aves_magnifier.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Cropper extends StatefulWidget {
  final AvesMagnifierController magnifierController;
  final TransformController transformController;
  final ValueNotifier<EdgeInsets> paddingNotifier;

  static const double handleDimension = kMinInteractiveDimension;
  static const EdgeInsets imagePadding = EdgeInsets.all(kMinInteractiveDimension);

  const Cropper({
    super.key,
    required this.magnifierController,
    required this.transformController,
    required this.paddingNotifier,
  });

  @override
  State<Cropper> createState() => _CropperState();
}

class _CropperState extends State<Cropper> with SingleTickerProviderStateMixin {
  final List<StreamSubscription> _subscriptions = [];
  final ValueNotifier<Size> _viewportSizeNotifier = ValueNotifier(Size.zero);
  final ValueNotifier<Rect> _outlineNotifier = ValueNotifier(Rect.zero);
  final ValueNotifier<int> _gridDivisionNotifier = ValueNotifier(0);
  late AnimationController _gridAnimationController;
  late Animation<double> _gridOpacity;

  static const double minDimension = Cropper.handleDimension;
  static const int panResizeGridDivision = 3;
  static const int straightenGridDivision = 9;
  static const double overOutlineFactor = .3;

  AvesMagnifierController get magnifierController => widget.magnifierController;

  TransformController get transformController => widget.transformController;

  @override
  void initState() {
    super.initState();
    final initialRegion = transformController.transformation.region;
    _viewportSizeNotifier.addListener(() => _initOutline(initialRegion));
    _gridAnimationController = AnimationController(
      duration: context.read<DurationsData>().viewerOverlayAnimation,
      vsync: this,
    );
    _gridOpacity = CurvedAnimation(
      parent: _gridAnimationController,
      curve: Curves.easeOutQuad,
    );
    _registerWidget(widget);
    _initOutline(initialRegion);
  }

  @override
  void didUpdateWidget(covariant Cropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _viewportSizeNotifier.dispose();
    _outlineNotifier.dispose();
    _gridDivisionNotifier.dispose();
    _gridAnimationController.dispose();
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(Cropper widget) {
    _subscriptions.add(widget.magnifierController.stateStream.listen(_onViewStateChanged));
    _subscriptions.add(widget.magnifierController.scaleBoundariesStream.listen(_onViewBoundariesChanged));
    _subscriptions.add(widget.transformController.eventStream.listen(_onTransformEvent));
  }

  void _unregisterWidget(Cropper widget) {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<EdgeInsets>(
        valueListenable: widget.paddingNotifier,
        builder: (context, padding, child) {
          return ValueListenableBuilder<Rect>(
            valueListenable: _outlineNotifier,
            builder: (context, outline, child) {
              if (outline.isEmpty) return const SizedBox();

              final outlineVisualRect = outline.translate(padding.left, padding.top);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          // use 1 painter per line so that the dashes of one line
                          // do not get offset depending on the previous line length
                          CustomPaint(
                            painter: DashedPathPainter(
                              originalPath: Path()..addPolygon([outlineVisualRect.topLeft, outlineVisualRect.topRight], false),
                              pathColor: CropperPainter.borderColor,
                              strokeWidth: CropperPainter.borderWidth,
                            ),
                          ),
                          CustomPaint(
                            painter: DashedPathPainter(
                              originalPath: Path()..addPolygon([outlineVisualRect.bottomLeft, outlineVisualRect.bottomRight], false),
                              pathColor: CropperPainter.borderColor,
                              strokeWidth: CropperPainter.borderWidth,
                            ),
                          ),
                          CustomPaint(
                            painter: DashedPathPainter(
                              originalPath: Path()..addPolygon([outlineVisualRect.topLeft, outlineVisualRect.bottomLeft], false),
                              pathColor: CropperPainter.borderColor,
                              strokeWidth: CropperPainter.borderWidth,
                            ),
                          ),
                          CustomPaint(
                            painter: DashedPathPainter(
                              originalPath: Path()..addPolygon([outlineVisualRect.topRight, outlineVisualRect.bottomRight], false),
                              pathColor: CropperPainter.borderColor,
                              strokeWidth: CropperPainter.borderWidth,
                            ),
                          ),
                          Positioned.fill(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _gridDivisionNotifier,
                              builder: (context, gridDivision, child) {
                                return ValueListenableBuilder<double>(
                                  valueListenable: _gridOpacity,
                                  builder: (context, gridOpacity, child) {
                                    return CustomPaint(
                                      painter: CropperPainter(
                                        rect: outlineVisualRect,
                                        gridOpacity: gridOpacity,
                                        gridDivision: gridDivision,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.topLeft,
                    setPosition: (v) => _handleOutline(
                      left: min(outline.right - minDimension, v.dx),
                      top: min(outline.bottom - minDimension, v.dy),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.topRight,
                    setPosition: (v) => _handleOutline(
                      top: min(outline.bottom - minDimension, v.dy),
                      right: max(outline.left + minDimension, v.dx),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.bottomRight,
                    setPosition: (v) => _handleOutline(
                      right: max(outline.left + minDimension, v.dx),
                      bottom: max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.bottomLeft,
                    setPosition: (v) => _handleOutline(
                      left: min(outline.right - minDimension, v.dx),
                      bottom: max(outline.top + minDimension, v.dy),
                    ),
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.topLeft),
                    setEdge: (v) => _handleOutline(left: min(outline.right - minDimension, v.left)),
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.topLeft, outline.topRight),
                    setEdge: (v) => _handleOutline(top: min(outline.bottom - minDimension, v.top)),
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomRight, outline.topRight),
                    setEdge: (v) => _handleOutline(right: max(outline.left + minDimension, v.right)),
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.bottomRight),
                    setEdge: (v) => _handleOutline(bottom: max(outline.top + minDimension, v.bottom)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _handleOutline({double? left, double? top, double? right, double? bottom}) {
    final currentState = _getViewState();
    final boundaries = magnifierController.scaleBoundaries;
    if (currentState == null || boundaries == null) return;

    final contentSize = boundaries.contentSize;
    final viewportSize = boundaries.viewportSize;

    final currentOutline = _outlineNotifier.value;
    final gestureOutline = CropRegion.fromOutline(
        currentState,
        Rect.fromLTRB(
          left ?? currentOutline.left,
          top ?? currentOutline.top,
          right ?? currentOutline.right,
          bottom ?? currentOutline.bottom,
        )).clamp(Rect.fromLTWH(0, 0, contentSize.width, contentSize.height)).toCropOutline(currentState);
    final clampedOutline = Rect.fromLTRB(
      max(gestureOutline.left, 0),
      max(gestureOutline.top, 0),
      min(gestureOutline.right, viewportSize.width),
      min(gestureOutline.bottom, viewportSize.height),
    );
    _setOutline(clampedOutline);
    _updateCropRegion();

    // zoom out when user gesture reaches outer edges

    if (gestureOutline.width - clampedOutline.width > precisionErrorTolerance || gestureOutline.height - clampedOutline.height > precisionErrorTolerance) {
      final targetOutline = Rect.lerp(clampedOutline, gestureOutline, overOutlineFactor)!;
      final targetRegion = CropRegion.fromOutline(currentState, targetOutline).clamp(Rect.fromLTWH(0, 0, contentSize.width, contentSize.height));
      final targetRegionSize = targetRegion.outsideRect.size;

      final nextScale = boundaries.clampScale(ScaleLevel.scaleForContained(viewportSize, targetRegionSize));
      final nextPosition = boundaries.clampPosition(
        position: boundaries.contentToStatePosition(nextScale, targetRegion.center),
        scale: nextScale,
      );
      final nextState = ViewState(
        position: nextPosition,
        scale: nextScale,
        viewportSize: viewportSize,
        contentSize: contentSize,
      );

      if (nextState != currentState) {
        magnifierController.update(
          position: nextPosition,
          scale: nextScale,
          source: ChangeSource.animation,
        );
        _setOutline(targetRegion.toCropOutline(nextState));
      }
    }
  }

  VertexHandle _buildVertexHandle({
    required EdgeInsets padding,
    required ValueGetter<Offset> getPosition,
    required ValueSetter<Offset> setPosition,
  }) {
    return VertexHandle(
      padding: padding,
      getPosition: getPosition,
      setPosition: setPosition,
      onDragStart: _onDragStart,
      onDragEnd: _onDragEnd,
    );
  }

  EdgeHandle _buildEdgeHandle({
    required EdgeInsets padding,
    required ValueGetter<Rect> getEdge,
    required ValueSetter<Rect> setEdge,
  }) {
    return EdgeHandle(
      padding: padding,
      getEdge: getEdge,
      setEdge: setEdge,
      onDragStart: _onDragStart,
      onDragEnd: _onDragEnd,
    );
  }

  void _onDragStart() {
    transformController.activity = TransformActivity.resize;
  }

  void _onDragEnd() {
    transformController.activity = TransformActivity.none;

    final boundaries = magnifierController.scaleBoundaries;
    if (boundaries == null) return;

    final contentSize = boundaries.contentSize;
    final viewportSize = boundaries.viewportSize;

    final region = transformController.transformation.region;
    final regionSize = region.outsideRect.size;

    final nextScale = boundaries.clampScale(ScaleLevel.scaleForContained(viewportSize, regionSize));
    final nextPosition = boundaries.clampPosition(
      position: boundaries.contentToStatePosition(nextScale, region.center),
      scale: nextScale,
    );
    final nextState = ViewState(
      position: nextPosition,
      scale: nextScale,
      viewportSize: viewportSize,
      contentSize: contentSize,
    );

    magnifierController.update(
      position: nextPosition,
      scale: nextScale,
      source: ChangeSource.animation,
    );
    _setOutline(region.toCropOutline(nextState));
  }

  void _onTransformEvent(TransformEvent event) {
    final activity = event.activity;
    switch (activity) {
      case TransformActivity.none:
        break;
      case TransformActivity.pan:
      case TransformActivity.resize:
        _gridDivisionNotifier.value = panResizeGridDivision;
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

  void _onViewStateChanged(MagnifierState state) {
    _setOutline(_outlineNotifier.value);
    switch (state.source) {
      case ChangeSource.internal:
      case ChangeSource.animation:
        break;
      case ChangeSource.gesture:
        _updateCropRegion();
        break;
    }
  }

  void _onViewBoundariesChanged(ScaleBoundaries scaleBoundaries) {
    _viewportSizeNotifier.value = scaleBoundaries.viewportSize;
  }

  ViewState? _getViewState() {
    final scaleBoundaries = magnifierController.scaleBoundaries;
    if (scaleBoundaries == null) return null;

    final state = magnifierController.currentState;
    return ViewState(
      position: state.position,
      scale: state.scale,
      viewportSize: scaleBoundaries.viewportSize,
      contentSize: scaleBoundaries.contentSize,
    );
  }

  void _initOutline(CropRegion region) {
    final viewState = _getViewState();
    if (viewState != null) {
      _setOutline(region.toCropOutline(viewState));
      _updateCropRegion();
    }
  }

  void _setOutline(Rect targetOutline) {
    final viewState = _getViewState();
    final contentSize = viewState?.contentSize;
    final viewportSize = viewState?.viewportSize;
    if (targetOutline.isEmpty || viewState == null || contentSize == null || viewportSize == null) return;

    // ensure outline is within content
    final targetRegion = CropRegion.fromOutline(viewState, targetOutline).clamp(Rect.fromLTWH(0, 0, contentSize.width, contentSize.height));
    var newOutline = targetRegion.toCropOutline(viewState);

    // ensure outline is large enough to be handled
    newOutline = Rect.fromLTWH(
      newOutline.left,
      newOutline.top,
      max(newOutline.width, minDimension),
      max(newOutline.height, minDimension),
    );

    // ensure outline is within viewport
    newOutline = Rect.fromLTRB(
      max(newOutline.left, 0),
      max(newOutline.top, 0),
      min(newOutline.right, viewportSize.width),
      min(newOutline.bottom, viewportSize.height),
    );

    _outlineNotifier.value = newOutline;
  }

  void _updateCropRegion() {
    final viewState = _getViewState();
    final outline = _outlineNotifier.value;
    if (viewState != null && !outline.isEmpty) {
      transformController.cropRegion = CropRegion.fromOutline(viewState, outline);
    }
  }
}
