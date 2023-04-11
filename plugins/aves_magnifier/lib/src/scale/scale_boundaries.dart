import 'dart:math';
import 'dart:ui';

import 'package:aves_magnifier/src/controller/controller.dart';
import 'package:aves_magnifier/src/controller/range.dart';
import 'package:aves_magnifier/src/scale/scale_level.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Internal class to wrap custom scale boundaries (min, max and initial)
/// Also, stores values regarding the two sizes: the container and the content.
@immutable
class ScaleBoundaries extends Equatable {
  final bool _allowOriginalScaleBeyondRange;
  final ScaleLevel _minScale;
  final ScaleLevel _maxScale;
  final ScaleLevel _initialScale;
  final Size viewportSize;
  final Size contentSize;

  static const Alignment basePosition = Alignment.center;

  @override
  List<Object?> get props => [_allowOriginalScaleBeyondRange, _minScale, _maxScale, _initialScale, viewportSize, contentSize];

  const ScaleBoundaries({
    required bool allowOriginalScaleBeyondRange,
    required ScaleLevel minScale,
    required ScaleLevel maxScale,
    required ScaleLevel initialScale,
    required this.viewportSize,
    required this.contentSize,
  })  : _allowOriginalScaleBeyondRange = allowOriginalScaleBeyondRange,
        _minScale = minScale,
        _maxScale = maxScale,
        _initialScale = initialScale;

  ScaleBoundaries copyWith({
    Size? contentSize,
  }) {
    return ScaleBoundaries(
      allowOriginalScaleBeyondRange: _allowOriginalScaleBeyondRange,
      minScale: _minScale,
      maxScale: _maxScale,
      initialScale: _initialScale,
      viewportSize: viewportSize,
      contentSize: contentSize ?? this.contentSize,
    );
  }

  double scaleForLevel(ScaleLevel level) {
    final factor = level.factor;
    switch (level.ref) {
      case ScaleReference.contained:
        return factor * ScaleLevel.scaleForContained(viewportSize, contentSize);
      case ScaleReference.covered:
        return factor * ScaleLevel.scaleForCovering(viewportSize, contentSize);
      case ScaleReference.absolute:
      default:
        return factor;
    }
  }

  double get originalScale => 1.0 / window.devicePixelRatio;

  double get minScale => {
        scaleForLevel(_minScale),
        _allowOriginalScaleBeyondRange ? originalScale : double.infinity,
        initialScale,
      }.fold(double.infinity, min);

  double get maxScale => {
        scaleForLevel(_maxScale),
        _allowOriginalScaleBeyondRange ? originalScale : double.negativeInfinity,
        initialScale,
      }.fold(0, max);

  double get initialScale => scaleForLevel(_initialScale);

  Offset get _viewportCenter => viewportSize.center(Offset.zero);

  Offset get _contentCenter => contentSize.center(Offset.zero);

  Offset viewportToStatePosition(AvesMagnifierController controller, Offset viewportPosition) {
    return viewportPosition - _viewportCenter - controller.position;
  }

  Offset viewportToContentPosition(AvesMagnifierController controller, Offset viewportPosition) {
    return viewportToStatePosition(controller, viewportPosition) / controller.scale! + _contentCenter;
  }

  Offset contentToStatePosition(double scale, Offset contentPosition) {
    return (_contentCenter - contentPosition) * scale;
  }

  EdgeRange getXEdges({required double scale}) {
    final computedWidth = contentSize.width * scale;
    final viewportWidth = viewportSize.width;

    final positionX = basePosition.x;
    final widthDiff = computedWidth - viewportWidth;

    final minX = ((positionX - 1).abs() / 2) * widthDiff * -1;
    final maxX = ((positionX + 1).abs() / 2) * widthDiff;
    return EdgeRange(minX, maxX);
  }

  EdgeRange getYEdges({required double scale}) {
    final computedHeight = contentSize.height * scale;
    final viewportHeight = viewportSize.height;

    final positionY = basePosition.y;
    final heightDiff = computedHeight - viewportHeight;

    final minY = ((positionY - 1).abs() / 2) * heightDiff * -1;
    final maxY = ((positionY + 1).abs() / 2) * heightDiff;
    return EdgeRange(minY, maxY);
  }

  double clampScale(double scale) => scale.clamp(minScale, maxScale);

  Offset clampPosition({required Offset position, required double scale}) {
    final computedWidth = contentSize.width * scale;
    final computedHeight = contentSize.height * scale;

    final viewportWidth = viewportSize.width;
    final viewportHeight = viewportSize.height;

    var finalX = 0.0;
    if (viewportWidth < computedWidth) {
      final range = getXEdges(scale: scale);
      finalX = position.dx.clamp(range.min, range.max);
    }

    var finalY = 0.0;
    if (viewportHeight < computedHeight) {
      final range = getYEdges(scale: scale);
      finalY = position.dy.clamp(range.min, range.max);
    }

    return Offset(finalX, finalY);
  }
}
