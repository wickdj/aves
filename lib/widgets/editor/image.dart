import 'dart:async';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/utils/vector_utils.dart';
import 'package:aves/widgets/editor/transform/controller.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/widgets/viewer/visual/conductor.dart';
import 'package:aves/widgets/viewer/visual/entry_page_view.dart';
import 'package:aves/widgets/viewer/visual/error.dart';
import 'package:aves/widgets/viewer/visual/raster.dart';
import 'package:aves/model/view_state.dart';
import 'package:aves_magnifier/aves_magnifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorImage extends StatefulWidget {
  final AvesEntry entry;

  const EditorImage({
    super.key,
    required this.entry,
  });

  @override
  State<EditorImage> createState() => _EditorImageState();
}

class _EditorImageState extends State<EditorImage> {
  late ValueNotifier<ViewState> _viewStateNotifier;
  late AvesMagnifierController _magnifierController;
  final List<StreamSubscription> _subscriptions = [];

  AvesEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant EditorImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry != widget.entry) {
      _unregisterWidget(oldWidget);
      _registerWidget(widget);
    }
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(EditorImage widget) {
    final entry = widget.entry;
    _viewStateNotifier = context.read<ViewStateConductor>().getOrCreateController(entry);
    _magnifierController = AvesMagnifierController();
    _subscriptions.add(_magnifierController.stateStream.listen(_onViewStateChanged));
    _subscriptions.add(_magnifierController.scaleBoundariesStream.listen(_onViewScaleBoundariesChanged));
  }

  void _unregisterWidget(EditorImage oldWidget) {
    _magnifierController.dispose();
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  @override
  Widget build(BuildContext context) {
    return MagnifierGestureDetectorScope(
      axis: const [Axis.horizontal, Axis.vertical],
      child: StreamBuilder<Transformation>(
        stream: context.select<TransformController, Stream<Transformation>>((v) => v.transformationStream),
        builder: (context, snapshot) {
          final imageToUserMatrix = (snapshot.data ?? Transformation.zero).matrix;
          final userToImageMatrix = Matrix4.identity()..copyInverse(imageToUserMatrix);
          return Transform(
            alignment: Alignment.center,
            transform: imageToUserMatrix,
            child: AvesMagnifier(
              key: Key('${entry.uri}_${entry.pageId}_${entry.dateModifiedSecs}'),
              controller: _magnifierController,
              childSize: entry.displaySize,
              allowOriginalScaleBeyondRange: false,
              velocityTransformer: (input) => userToImageMatrix.transform3(input.toVector3).toOffset,
              minScale: const ScaleLevel(ref: ScaleReference.contained),
              maxScale: EntryPageView.rasterMaxScale,
              initialScale: const ScaleLevel(ref: ScaleReference.contained),
              scaleStateCycle: defaultScaleStateCycle,
              applyScale: false,
              child: RasterImageView(
                entry: entry,
                viewStateNotifier: _viewStateNotifier,
                errorBuilder: (context, error, stackTrace) => ErrorView(
                  entry: entry,
                  onTap: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onViewStateChanged(MagnifierState v) {
    _viewStateNotifier.value = _viewStateNotifier.value.copyWith(
      position: v.position,
      scale: v.scale,
    );
  }

  void _onViewScaleBoundariesChanged(ScaleBoundaries v) {
    _viewStateNotifier.value = _viewStateNotifier.value.copyWith(
      viewportSize: v.viewportSize,
      contentSize: v.childSize,
    );
  }
}
