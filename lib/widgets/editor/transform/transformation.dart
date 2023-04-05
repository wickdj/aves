import 'dart:async';
import 'dart:math' as math;

import 'package:aves_model/aves_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TransformController {
  ValueNotifier<CropAspectRatio> aspectRatioNotifier = ValueNotifier(CropAspectRatio.free);

  Transformation _transformation = Transformation.zero;

  Transformation get transformation => _transformation;

  bool get modified => _transformation != Transformation.zero;

  final StreamController<Transformation> _transformationStreamController = StreamController.broadcast();

  Stream<Transformation> get transformationStream => _transformationStreamController.stream;

  final StreamController<TransformEvent> _eventStreamController = StreamController.broadcast();

  Stream<TransformEvent> get eventStream => _eventStreamController.stream;

  static const double straightenDegreesMin = -45;
  static const double straightenDegreesMax = 45;

  final Size displaySize;

  TransformController(this.displaySize) {
    reset();
    aspectRatioNotifier.addListener(_onAspectRatioChanged);
  }

  void dispose() {
    aspectRatioNotifier.dispose();
  }

  void reset() {
    _transformation = Transformation.zero.copyWith(
      cropImageRect: Rect.fromLTWH(0, 0, displaySize.width, displaySize.height),
    );
    _transformationStreamController.add(_transformation);
  }

  void flip() {
    _transformation = _transformation.copyWith(
      orientation: _transformation.orientation.flip(),
      straightenDegrees: -transformation.straightenDegrees,
    );
    _transformationStreamController.add(_transformation);
  }

  void rotateClockwise() {
    _transformation = _transformation.copyWith(
      orientation: _transformation.orientation.rotateClockwise(),
    );
    _transformationStreamController.add(_transformation);
  }

  set straightenDegrees(double straightenDegrees) {
    _transformation = _transformation.copyWith(
      straightenDegrees: straightenDegrees.clamp(straightenDegreesMin, straightenDegreesMax),
    );
    _transformationStreamController.add(_transformation);
  }

  set cropImageRect(Rect rect) {
    _transformation = _transformation.copyWith(
      cropImageRect: rect,
    );
    _transformationStreamController.add(_transformation);
  }
  
  set activity(TransformActivity activity) => _eventStreamController.add(TransformEvent(activity: activity));

  void _onAspectRatioChanged() {
    // TODO TLAD [crop] apply
  }
}

@immutable
class Transformation extends Equatable {
  final TransformOrientation orientation;
  final double straightenDegrees;
  final Rect cropImageRect;

  @override
  List<Object?> get props => [orientation, straightenDegrees, cropImageRect];

  static const zero = Transformation(
    orientation: TransformOrientation.normal,
    straightenDegrees: 0,
    cropImageRect: Rect.zero,
  );

  const Transformation({
    required this.orientation,
    required this.straightenDegrees,
    required this.cropImageRect,
  });

  Transformation copyWith({
    TransformOrientation? orientation,
    double? straightenDegrees,
    Rect? cropImageRect,
  }) {
    return Transformation(
      orientation: orientation ?? this.orientation,
      straightenDegrees: straightenDegrees ?? this.straightenDegrees,
      cropImageRect: cropImageRect ?? this.cropImageRect,
    );
  }

  Matrix4 get matrix => _orientationMatrix..multiply(_straightenMatrix);

  Matrix4 get _orientationMatrix {
    final matrix = Matrix4.identity();
    switch (orientation) {
      case TransformOrientation.normal:
        break;
      case TransformOrientation.rotate90:
        matrix.rotateZ(math.pi / 2);
        break;
      case TransformOrientation.rotate180:
        matrix.rotateZ(math.pi);
        break;
      case TransformOrientation.rotate270:
        matrix.rotateZ(3 * math.pi / 2);
        break;
      case TransformOrientation.transverse:
        matrix.scale(-1.0, 1.0, 1.0);
        matrix.rotateZ(-3 * math.pi / 2);
        break;
      case TransformOrientation.flipVertical:
        matrix.scale(1.0, -1.0, 1.0);
        break;
      case TransformOrientation.transpose:
        matrix.scale(-1.0, 1.0, 1.0);
        matrix.rotateZ(-1 * math.pi / 2);
        break;
      case TransformOrientation.flipHorizontal:
        matrix.scale(-1.0, 1.0, 1.0);
        break;
    }
    return matrix;
  }

  Matrix4 get _straightenMatrix => Matrix4.rotationZ(degToRadian((orientation.isFlipped ? -1 : 1) * straightenDegrees));
}

@immutable
class TransformEvent {
  final TransformActivity activity;

  const TransformEvent({
    required this.activity,
  });
}

enum TransformActivity { none, resize, straighten }

enum TransformOrientation { normal, rotate90, rotate180, rotate270, transverse, flipVertical, transpose, flipHorizontal }

extension ExtraTransformOrientation on TransformOrientation {
  TransformOrientation flip() {
    switch (this) {
      case TransformOrientation.normal:
        return TransformOrientation.flipHorizontal;
      case TransformOrientation.rotate90:
        return TransformOrientation.transverse;
      case TransformOrientation.rotate180:
        return TransformOrientation.flipVertical;
      case TransformOrientation.rotate270:
        return TransformOrientation.transpose;
      case TransformOrientation.transverse:
        return TransformOrientation.rotate90;
      case TransformOrientation.flipVertical:
        return TransformOrientation.rotate180;
      case TransformOrientation.transpose:
        return TransformOrientation.rotate270;
      case TransformOrientation.flipHorizontal:
        return TransformOrientation.normal;
    }
  }

  bool get isFlipped {
    switch (this) {
      case TransformOrientation.normal:
      case TransformOrientation.rotate90:
      case TransformOrientation.rotate180:
      case TransformOrientation.rotate270:
        return false;
      case TransformOrientation.transverse:
      case TransformOrientation.flipVertical:
      case TransformOrientation.transpose:
      case TransformOrientation.flipHorizontal:
        return true;
    }
  }

  TransformOrientation rotateClockwise() {
    switch (this) {
      case TransformOrientation.normal:
        return TransformOrientation.rotate90;
      case TransformOrientation.rotate90:
        return TransformOrientation.rotate180;
      case TransformOrientation.rotate180:
        return TransformOrientation.rotate270;
      case TransformOrientation.rotate270:
        return TransformOrientation.normal;
      case TransformOrientation.transverse:
        return TransformOrientation.flipHorizontal;
      case TransformOrientation.flipVertical:
        return TransformOrientation.transverse;
      case TransformOrientation.transpose:
        return TransformOrientation.flipVertical;
      case TransformOrientation.flipHorizontal:
        return TransformOrientation.transpose;
    }
  }
}
