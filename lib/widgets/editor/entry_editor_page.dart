import 'package:aves/model/entry/entry.dart';
import 'package:aves/widgets/editor/controls.dart';
import 'package:aves/widgets/editor/image.dart';
import 'package:aves/widgets/editor/transform/cropper.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/widgets/viewer/overlay/minimap.dart';
import 'package:aves/widgets/viewer/providers.dart';
import 'package:aves/widgets/viewer/visual/conductor.dart';
import 'package:aves/widgets/viewer/visual/state.dart';
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
                        Cropper(
                          controller: _transformController,
                          viewStateNotifier: viewStateNotifier,
                        ),
                        PositionedDirectional(
                          start: 8,
                          bottom: 8,
                          child: Minimap(viewStateNotifier: viewStateNotifier),
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
