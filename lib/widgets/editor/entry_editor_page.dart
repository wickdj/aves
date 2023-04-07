import 'dart:math';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/editor/control_panel.dart';
import 'package:aves/widgets/editor/image.dart';
import 'package:aves/widgets/editor/transform/controller.dart';
import 'package:aves/widgets/editor/transform/cropper.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/widgets/viewer/overlay/minimap.dart';
import 'package:aves/widgets/viewer/providers.dart';
import 'package:aves/widgets/viewer/visual/conductor.dart';
import 'package:aves/model/view_state.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageEditorPage extends StatefulWidget {
  static const routeName = '/image_editor';

  final AvesEntry entry;

  const ImageEditorPage({
    super.key,
    required this.entry,
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final ValueNotifier<EditorAction?> _actionNotifier = ValueNotifier(null);
  late final TransformController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = TransformController(widget.entry.displaySize);
  }

  @override
  void dispose() {
    _actionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiProvider(
        providers: [
          ViewStateConductorProvider(),
          Provider<TransformController>.value(value: _transformController),
        ],
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Selector<ViewStateConductor, ValueNotifier<ViewState>>(
                  selector: (context, v) => v.getOrCreateController(widget.entry),
                  builder: (context, viewStateNotifier, child) {
                    return Stack(
                      children: [
                        ClipRect(
                          child: EditorImage(
                            entry: widget.entry,
                          ),
                        ),
                        if (settings.showOverlayMinimap)
                          PositionedDirectional(
                            start: 8,
                            bottom: 8,
                            child: Minimap(viewStateNotifier: viewStateNotifier),
                          ),
                        // StreamBuilder<Transformation>(
                        //   stream: _transformController.transformationStream,
                        //   builder: (context, snapshot) {
                        //     final cropRegion = _transformController.transformation.region;
                        //     final rect = cropRegion.toCropOutline(viewStateNotifier.value);
                        //     return IgnorePointer(
                        //       child: Padding(
                        //         padding: EdgeInsets.only(top: max(0, rect.top), left: max(0, rect.left)),
                        //         child: Container(
                        //           width: rect.width,
                        //           height: rect.height,
                        //           color: Colors.amber.withOpacity(.2),
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                        EditorImageOverlay(
                          actionNotifier: _actionNotifier,
                          viewStateNotifier: viewStateNotifier,
                        ),
                      ],
                    );
                  },
                ),
              ),
              EditorControlPanel(
                entry: widget.entry,
                actionNotifier: _actionNotifier,
              ),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}

class EditorImageOverlay extends StatelessWidget {
  final ValueNotifier<EditorAction?> actionNotifier;
  final ValueNotifier<ViewState> viewStateNotifier;

  const EditorImageOverlay({
    super.key,
    required this.actionNotifier,
    required this.viewStateNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorAction?>(
      valueListenable: actionNotifier,
      builder: (context, action, child) {
        switch (action) {
          case EditorAction.transform:
            return Cropper(
              controller: context.watch<TransformController>(),
              viewStateNotifier: viewStateNotifier,
            );
          case null:
            return const SizedBox();
        }
      },
    );
  }
}
