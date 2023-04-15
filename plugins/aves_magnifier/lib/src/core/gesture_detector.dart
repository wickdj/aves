import 'package:aves_magnifier/src/core/scale_gesture_recognizer.dart';
import 'package:aves_magnifier/src/pan/edge_hit_detector.dart';
import 'package:aves_magnifier/src/pan/gesture_detector_scope.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class MagnifierGestureDetector extends StatefulWidget {
  const MagnifierGestureDetector({
    super.key,
    required this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onTapDown,
    this.onTapUp,
    this.onDoubleTap,
    this.behavior,
    this.child,
  });

  final EdgeHitDetector hitDetector;
  final void Function(ScaleStartDetails details, bool doubleTap)? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onDoubleTap;

  final HitTestBehavior? behavior;
  final Widget? child;

  @override
  State<MagnifierGestureDetector> createState() => _MagnifierGestureDetectorState();
}

class _MagnifierGestureDetectorState extends State<MagnifierGestureDetector> {
  final ValueNotifier<TapDownDetails?> doubleTapDetails = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final gestureSettings = context.select<MediaQueryData, DeviceGestureSettings>((mq) => mq.gestureSettings);
    final gestures = <Type, GestureRecognizerFactory>{};

    if (widget.onTapDown != null || widget.onTapUp != null) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (instance) {
          instance
            ..onTapDown = widget.onTapDown
            ..onTapUp = widget.onTapUp;
        },
      );
    }

    final scope = MagnifierGestureDetectorScope.maybeOf(context);
    if (scope != null) {
      gestures[MagnifierGestureRecognizer] = GestureRecognizerFactoryWithHandlers<MagnifierGestureRecognizer>(
        () => MagnifierGestureRecognizer(
          debugOwner: this,
          scope: scope,
          doubleTapDetails: doubleTapDetails,
        ),
        (instance) {
          instance
            ..hitDetector = widget.hitDetector
            ..onStart = widget.onScaleStart != null ? (details) => widget.onScaleStart!(details, doubleTapDetails.value != null) : null
            ..onUpdate = widget.onScaleUpdate
            ..onEnd = widget.onScaleEnd
            ..gestureSettings = gestureSettings;
        },
      );
    }

    gestures[DoubleTapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      () => DoubleTapGestureRecognizer(debugOwner: this),
      (instance) {
        final onDoubleTap = widget.onDoubleTap;
        instance
          ..onDoubleTapCancel = _onDoubleTapCancel
          ..onDoubleTapDown = _onDoubleTapDown
          ..onDoubleTap = onDoubleTap != null
              ? () {
                  onDoubleTap(doubleTapDetails.value!);
                  doubleTapDetails.value = null;
                }
              : null;
      },
    );

    return RawGestureDetector(
      gestures: gestures,
      behavior: widget.behavior ?? HitTestBehavior.translucent,
      child: widget.child,
    );
  }

  void _onDoubleTapCancel() => doubleTapDetails.value = null;

  void _onDoubleTapDown(TapDownDetails details) => doubleTapDetails.value = details;
}
