import 'dart:async';
import 'dart:math';

import 'package:aves/model/view_state.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/utils/math_utils.dart';
import 'package:aves/widgets/common/fx/dashed_path_painter.dart';
import 'package:aves/widgets/editor/transform/controller.dart';
import 'package:aves/widgets/editor/transform/crop_region.dart';
import 'package:aves/widgets/editor/transform/handles.dart';
import 'package:aves/widgets/editor/transform/painter.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves_magnifier/aves_magnifier.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

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

  Transformation get transformation => transformController.transformation;

  @override
  void initState() {
    super.initState();
    final initialRegion = transformation.region;
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
    _subscriptions.add(widget.transformController.transformationStream.map((v) => v.orientation).distinct().listen(_onOrientationChanged));
    _subscriptions.add(widget.transformController.transformationStream.map((v) => v.straightenDegrees).distinct().listen(_onStraightenDegreesChanged));
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
                      topLeft: Offset(min(outline.right - minDimension, v.dx), min(outline.bottom - minDimension, v.dy)),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.topRight,
                    setPosition: (v) => _handleOutline(
                      topRight: Offset(max(outline.left + minDimension, v.dx), min(outline.bottom - minDimension, v.dy)),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.bottomRight,
                    setPosition: (v) => _handleOutline(
                      bottomRight: Offset(max(outline.left + minDimension, v.dx), max(outline.top + minDimension, v.dy)),
                    ),
                  ),
                  _buildVertexHandle(
                    padding: padding,
                    getPosition: () => outline.bottomLeft,
                    setPosition: (v) => _handleOutline(
                      bottomLeft: Offset(min(outline.right - minDimension, v.dx), max(outline.top + minDimension, v.dy)),
                    ),
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.topLeft),
                    setEdge: (v) {
                      final left = min(outline.right - minDimension, v.left);
                      return _handleOutline(
                        topLeft: Offset(left, outline.top),
                        bottomLeft: Offset(left, outline.bottom),
                      );
                    },
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.topLeft, outline.topRight),
                    setEdge: (v) {
                      final top = min(outline.bottom - minDimension, v.top);
                      return _handleOutline(
                        topLeft: Offset(outline.left, top),
                        topRight: Offset(outline.right, top),
                      );
                    },
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomRight, outline.topRight),
                    setEdge: (v) {
                      final right = max(outline.left + minDimension, v.right);
                      return _handleOutline(
                        topRight: Offset(right, outline.top),
                        bottomRight: Offset(right, outline.bottom),
                      );
                    },
                  ),
                  _buildEdgeHandle(
                    padding: padding,
                    getEdge: () => Rect.fromPoints(outline.bottomLeft, outline.bottomRight),
                    setEdge: (v) {
                      final bottom = max(outline.top + minDimension, v.bottom);
                      return _handleOutline(
                        bottomLeft: Offset(outline.left, bottom),
                        bottomRight: Offset(outline.right, bottom),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _handleOutline({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    final currentState = _getViewState();
    final boundaries = magnifierController.scaleBoundaries;
    if (currentState == null || boundaries == null) return;

    final gestureRegion = transformation.straightenDegrees == 0
        ? _gestureRegionWithinStraightContent(
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft,
            currentState: currentState,
          )
        : _gestureRegionWithinRotatedContent(
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft,
            currentState: currentState,
            boundaries: boundaries,
          );

    final viewportSize = boundaries.viewportSize;

    final gestureOutline = _regionToOutline(currentState, gestureRegion);
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
      final targetRegion = _regionFromOutline(currentState, targetOutline);

      final nextState = _viewStateForContainedRegion(boundaries, targetRegion);
      if (nextState != currentState) {
        magnifierController.update(
          position: nextState.position,
          scale: nextState.scale,
          source: ChangeSource.animation,
        );
        _setOutline(_regionToOutline(nextState, targetRegion));
      }
    }
  }

  CropRegion _gestureRegionWithinStraightContent({
    required Offset? topLeft,
    required Offset? topRight,
    required Offset? bottomRight,
    required Offset? bottomLeft,
    required ViewState currentState,
  }) {
    final currentOutline = _outlineNotifier.value;
    final targetOutline = Rect.fromLTRB(
      topLeft?.dx ?? bottomLeft?.dx ?? currentOutline.left,
      topLeft?.dy ?? topRight?.dy ?? currentOutline.top,
      topRight?.dx ?? bottomRight?.dx ?? currentOutline.right,
      bottomLeft?.dy ?? bottomRight?.dy ?? currentOutline.bottom,
    );
    return _regionFromOutline(currentState, targetOutline);
  }

  CropRegion _gestureRegionWithinRotatedContent({
    required Offset? topLeft,
    required Offset? topRight,
    required Offset? bottomRight,
    required Offset? bottomLeft,
    required ViewState currentState,
    required ScaleBoundaries boundaries,
  }) {
    final handlerType = _handlerTypeFor(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
    )!;

    final currentOutline = _outlineNotifier.value;
    final targetOutline = Rect.fromLTRB(
      topLeft?.dx ?? bottomLeft?.dx ?? currentOutline.left,
      topLeft?.dy ?? topRight?.dy ?? currentOutline.top,
      topRight?.dx ?? bottomRight?.dx ?? currentOutline.right,
      bottomLeft?.dy ?? bottomRight?.dy ?? currentOutline.bottom,
    );
    topLeft = targetOutline.topLeft;
    topRight = targetOutline.topRight;
    bottomRight = targetOutline.bottomRight;
    bottomLeft = targetOutline.bottomLeft;

    final contentRect = Offset.zero & boundaries.contentSize;
    final contentLeft = Tuple2(contentRect.topLeft, contentRect.bottomLeft);
    final contentTop = Tuple2(contentRect.topLeft, contentRect.topRight);
    final contentRight = Tuple2(contentRect.topRight, contentRect.bottomRight);
    final contentBottom = Tuple2(contentRect.bottomLeft, contentRect.bottomRight);

    final regionToOutlineMatrix = _getRegionToOutlineMatrix(currentState);
    final outlineToRegionMatrix = Matrix4.inverted(regionToOutlineMatrix);

    final regionTopLeft = outlineToRegionMatrix.transformOffset(topLeft);
    final regionTopRight = outlineToRegionMatrix.transformOffset(topRight);
    final regionBottomRight = outlineToRegionMatrix.transformOffset(bottomRight);
    final regionBottomLeft = outlineToRegionMatrix.transformOffset(bottomLeft);
    final regionLeft = Tuple2(regionTopLeft, regionBottomLeft);
    final regionTop = Tuple2(regionTopLeft, regionTopRight);
    final regionRight = Tuple2(regionTopRight, regionBottomRight);
    final regionBottom = Tuple2(regionBottomLeft, regionBottomRight);

    final contentEdges = [contentTop, contentRight, contentBottom, contentLeft];
    Offset? contentIntersection(Tuple2<Offset, Offset> s, {required Set<Offset> excluded}) {
      const tolerancePx = 1;
      for (final edge in contentEdges) {
        final intersection = segmentIntersection(s, edge);
        if (intersection != null && excluded.every((v) => (intersection.dx - v.dx).abs() > tolerancePx || (intersection.dy - v.dy).abs() > tolerancePx)) {
          return intersection;
        }
      }
      return null;
    }

    var left = targetOutline.left;
    var top = targetOutline.top;
    var right = targetOutline.right;
    var bottom = targetOutline.bottom;
    switch (handlerType) {
      case _HandlerType.topEdge:
        final hitTopLeft = contentIntersection(regionLeft, excluded: {regionBottomLeft});
        final hitTopRight = contentIntersection(regionRight, excluded: {regionBottomRight});
        final tl = regionToOutlineMatrix.transformOffset(hitTopLeft ?? regionTopLeft);
        final tr = regionToOutlineMatrix.transformOffset(hitTopRight ?? regionTopRight);
        top = max(tl.dy, tr.dy);
        left = max(tl.dx, tr.dx);
        right = min(tl.dx, tr.dx);
        break;
      case _HandlerType.rightEdge:
        final hitTopRight = contentIntersection(regionTop, excluded: {regionTopLeft});
        final hitBottomRight = contentIntersection(regionBottom, excluded: {regionBottomLeft});
        final tr = regionToOutlineMatrix.transformOffset(hitTopRight ?? regionTopRight);
        final br = regionToOutlineMatrix.transformOffset(hitBottomRight ?? regionBottomRight);
        right = min(tr.dx, br.dx);
        top = max(tr.dy, br.dy);
        bottom = min(tr.dy, br.dy);
        break;
      case _HandlerType.bottomEdge:
        final hitBottomLeft = contentIntersection(regionLeft, excluded: {regionTopLeft});
        final hitBottomRight = contentIntersection(regionRight, excluded: {regionTopRight});
        final bl = regionToOutlineMatrix.transformOffset(hitBottomLeft ?? regionBottomLeft);
        final br = regionToOutlineMatrix.transformOffset(hitBottomRight ?? regionBottomRight);
        bottom = min(bl.dy, br.dy);
        left = max(bl.dx, br.dx);
        right = min(bl.dx, br.dx);
        break;
      case _HandlerType.leftEdge:
        final hitTopLeft = contentIntersection(regionTop, excluded: {regionTopRight});
        final hitBottomLeft = contentIntersection(regionBottom, excluded: {regionBottomRight});
        final tl = regionToOutlineMatrix.transformOffset(hitTopLeft ?? regionTopLeft);
        final bl = regionToOutlineMatrix.transformOffset(hitBottomLeft ?? regionBottomLeft);
        left = max(tl.dx, bl.dx);
        top = max(tl.dy, bl.dy);
        bottom = min(tl.dy, bl.dy);
        break;
      // case _HandlerType.topLeftCorner:
      //   final interTop = contentIntersection(regionTop, excluded: {regionTopRight});
      //   final interLeft = contentIntersection(regionLeft, excluded: {regionBottomLeft});
      //   final tl = regionToOutlineMatrix.transformOffset(interTop ?? interLeft ?? regionTopLeft);
      //   left = tl.dx;
      //   top = tl.dy;
      //   break;
      // case _HandlerType.topRightCorner:
      //   final interTop = contentIntersection(regionTop, excluded: {regionTopLeft});
      //   final interRight = contentIntersection(regionRight, excluded: {regionBottomRight});
      //   final tr = regionToOutlineMatrix.transformOffset(interTop ?? interRight ?? regionTopRight);
      //   top = tr.dy;
      //   right = tr.dx;
      //   break;
      // case _HandlerType.bottomRightCorner:
      //   final interBottom = contentIntersection(regionBottom, excluded: {regionBottomLeft});
      //   final interRight = contentIntersection(regionRight, excluded: {regionTopRight});
      //   final br = regionToOutlineMatrix.transformOffset(interBottom ?? interRight ?? regionBottomRight);
      //   right = br.dx;
      //   bottom = br.dy;
      //   break;
      // case _HandlerType.bottomLeftCorner:
      //   final hitBottomRight = contentIntersection(regionRight, excluded: {regionTopRight, regionBottomLeft});
      //   final hitTopLeft = contentIntersection(regionTop, excluded: {regionTopRight, regionBottomLeft});
      //   final hitBottomLeft = hitBottomRight == null && hitTopLeft == null ? contentIntersection(regionBottom, excluded: {regionBottomRight}) ?? contentIntersection(regionLeft, excluded: {regionTopLeft}) : null;
      //   debugPrint('TLAD hitTopLeft=$hitTopLeft hitBottomLeft=$hitBottomLeft hitBottomRight=$hitBottomRight');
      //   final tl = regionToOutlineMatrix.transformOffset(hitTopLeft ?? regionTopLeft);
      //   final br = regionToOutlineMatrix.transformOffset(hitBottomRight ?? regionBottomRight);
      //   final bl = regionToOutlineMatrix.transformOffset(hitBottomLeft ?? regionBottomLeft);
      //   left = max(tl.dx, bl.dx);
      //   top = tl.dy;
      //   right = br.dx;
      //   bottom = min(bl.dy, br.dy);
      //   break;
      default:
        break;
    }

    return _regionFromOutline(currentState, Rect.fromLTRB(left, top, right, bottom));
  }

  _HandlerType? _handlerTypeFor({
    required Offset? topLeft,
    required Offset? topRight,
    required Offset? bottomRight,
    required Offset? bottomLeft,
  }) {
    if (topLeft != null && topRight != null) return _HandlerType.topEdge;
    if (topRight != null && bottomRight != null) return _HandlerType.rightEdge;
    if (bottomLeft != null && bottomRight != null) return _HandlerType.bottomEdge;
    if (topLeft != null && bottomLeft != null) return _HandlerType.leftEdge;

    if (topLeft != null) return _HandlerType.topLeftCorner;
    if (topRight != null) return _HandlerType.topRightCorner;
    if (bottomRight != null) return _HandlerType.bottomRightCorner;
    if (bottomLeft != null) return _HandlerType.bottomLeftCorner;

    return null;
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
    _showRegion();
  }

  void _showRegion() {
    final boundaries = magnifierController.scaleBoundaries;
    if (boundaries == null) return;

    final region = transformation.region;
    final nextState = _viewStateForContainedRegion(boundaries, region);

    magnifierController.update(
      position: nextState.position,
      scale: nextState.scale,
      source: ChangeSource.animation,
    );
    _setOutline(_regionToOutline(nextState, region));
  }

  ViewState _viewStateForContainedRegion(ScaleBoundaries boundaries, CropRegion region) {
    final regionSize = MatrixUtils.transformRect(transformation.matrix, region.outsideRect).size;
    final nextScale = boundaries.clampScale(ScaleLevel.scaleForContained(boundaries.viewportSize, regionSize));
    final nextPosition = boundaries.clampPosition(
      position: boundaries.contentToStatePosition(nextScale, region.center),
      scale: nextScale,
    );
    return ViewState(
      position: nextPosition,
      scale: nextScale,
      viewportSize: boundaries.viewportSize,
      contentSize: boundaries.contentSize,
    );
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

  void _onOrientationChanged(TransformOrientation orientation) {
    _showRegion();
  }

  void _onStraightenDegreesChanged(double degrees) {
    _updateCropRegion();
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
      _setOutline(_regionToOutline(viewState, region));
      _updateCropRegion();
    }
  }

  void _setOutline(Rect targetOutline) {
    final viewState = _getViewState();
    final viewportSize = viewState?.viewportSize;
    if (targetOutline.isEmpty || viewState == null || viewportSize == null) return;

    // ensure outline is within content
    final targetRegion = _regionFromOutline(viewState, targetOutline);
    var newOutline = _regionToOutline(viewState, targetRegion);

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
      transformController.cropRegion = _regionFromOutline(viewState, outline);
    }
  }

  Matrix4 _getRegionToOutlineMatrix(ViewState viewState) {
    final magnifierMatrix = viewState.matrix;

    final viewportCenter = viewState.viewportSize!.center(Offset.zero);
    final transformOrigin = Matrix4.inverted(magnifierMatrix).transformOffset(viewportCenter);
    final transformMatrix = Matrix4.identity()
      ..translate(transformOrigin.dx, transformOrigin.dy)
      ..multiply(transformation.matrix)
      ..translate(-transformOrigin.dx, -transformOrigin.dy);

    return magnifierMatrix..multiply(transformMatrix);
  }

  CropRegion _regionFromOutline(ViewState viewState, Rect outline) {
    final regionToOutlineMatrix = _getRegionToOutlineMatrix(viewState);
    final outlineToRegionMatrix = regionToOutlineMatrix..invert();

    final region = CropRegion(
      topLeft: outlineToRegionMatrix.transformOffset(outline.topLeft),
      topRight: outlineToRegionMatrix.transformOffset(outline.topRight),
      bottomRight: outlineToRegionMatrix.transformOffset(outline.bottomRight),
      bottomLeft: outlineToRegionMatrix.transformOffset(outline.bottomLeft),
    );

    final rect = Offset.zero & viewState.contentSize!;
    double clampX(double dx) => dx.clamp(rect.left, rect.right);
    double clampY(double dy) => dy.clamp(rect.top, rect.bottom);
    Offset clampPoint(Offset v) => Offset(clampX(v.dx), clampY(v.dy));
    final clampedRegion = CropRegion(
      topLeft: clampPoint(region.topLeft),
      topRight: clampPoint(region.topRight),
      bottomRight: clampPoint(region.bottomRight),
      bottomLeft: clampPoint(region.bottomLeft),
    );
    return clampedRegion;
  }

  Rect _regionToOutline(ViewState viewState, CropRegion region) {
    final matrix = _getRegionToOutlineMatrix(viewState);

    final points = region.corners.map(matrix.transformOffset).toSet();
    final xMin = points.map((v) => v.dx).min;
    final xMax = points.map((v) => v.dx).max;
    final yMin = points.map((v) => v.dy).min;
    final yMax = points.map((v) => v.dy).max;
    return Rect.fromPoints(Offset(xMin, yMin), Offset(xMax, yMax));
  }
}

enum _HandlerType { topEdge, rightEdge, bottomEdge, leftEdge, topLeftCorner, topRightCorner, bottomRightCorner, bottomLeftCorner }
