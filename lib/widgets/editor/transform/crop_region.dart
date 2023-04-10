import 'dart:ui';

import 'package:aves/model/view_state.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class CropRegion extends Equatable {
  final Offset topLeft, topRight, bottomRight, bottomLeft;

  List<Offset> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  Offset get center => (topLeft + bottomRight) / 2;

  Rect get outsideRect {
    final xMin = corners.map((v) => v.dx).min;
    final xMax = corners.map((v) => v.dx).max;
    final yMin = corners.map((v) => v.dy).min;
    final yMax = corners.map((v) => v.dy).max;
    return Rect.fromPoints(Offset(xMin, yMin), Offset(xMax, yMax));
  }

  @override
  List<Object?> get props => [topLeft, topRight, bottomRight, bottomLeft];

  const CropRegion({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  static const CropRegion zero = CropRegion(
    topLeft: Offset.zero,
    topRight: Offset.zero,
    bottomRight: Offset.zero,
    bottomLeft: Offset.zero,
  );

  factory CropRegion.fromRect(Rect rect) {
    return CropRegion(
      topLeft: rect.topLeft,
      topRight: rect.topRight,
      bottomRight: rect.bottomRight,
      bottomLeft: rect.bottomLeft,
    );
  }

  factory CropRegion.fromOutline(ViewState viewState, Rect outline) {
    final points = [
      outline.topLeft,
      outline.topRight,
      outline.bottomRight,
      outline.bottomLeft,
    ].map(viewState.toContentPoint).toList(); // _matrix.transform3(v.toVector3).toOffset).toList();
    return CropRegion(
      topLeft: points[0],
      topRight: points[1],
      bottomRight: points[2],
      bottomLeft: points[3],
    );
  }

  Rect toCropOutline(ViewState viewState) {
    final points = corners.map(viewState.toViewportPoint).toSet();
    final xMin = points.map((v) => v.dx).min;
    final xMax = points.map((v) => v.dx).max;
    final yMin = points.map((v) => v.dy).min;
    final yMax = points.map((v) => v.dy).max;
    return Rect.fromPoints(Offset(xMin, yMin), Offset(xMax, yMax));
  }

  CropRegion clamp(Rect rect) {
    double clampX(double dx) => dx.clamp(rect.left, rect.right);
    double clampY(double dy) => dy.clamp(rect.top, rect.bottom);
    Offset clampPoint(Offset v) => Offset(clampX(v.dx), clampY(v.dy));
    return CropRegion(
      topLeft: clampPoint(topLeft),
      topRight: clampPoint(topRight),
      bottomRight: clampPoint(bottomRight),
      bottomLeft: clampPoint(bottomLeft),
    );
  }
}
