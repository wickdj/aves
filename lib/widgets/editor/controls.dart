import 'package:aves/model/entry/entry.dart';
import 'package:aves/view/view.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/buttons/overlay_button.dart';
import 'package:aves/widgets/editor/transform/controls.dart';
import 'package:aves/widgets/editor/transform/transformation.dart';
import 'package:aves/widgets/viewer/overlay/viewer_buttons.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorControlPanel extends StatelessWidget {
  final AvesEntry entry;
  final ValueNotifier<EditorAction?> actionNotifier;

  static const padding = ViewerButtonRowContent.padding;
  static const actions = [
    EditorAction.transform,
  ];

  const EditorControlPanel({
    super.key,
    required this.entry,
    required this.actionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (actionNotifier.value != null) {
          _cancelAction(context);
          return SynchronousFuture(false);
        }
        return SynchronousFuture(true);
      },
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: TooltipTheme(
          data: TooltipTheme.of(context).copyWith(
            preferBelow: false,
          ),
          child: ValueListenableBuilder<EditorAction?>(
            valueListenable: actionNotifier,
            builder: (context, action, child) {
              switch (action) {
                case EditorAction.transform:
                  return TransformControlPanel(
                    entry: entry,
                    onCancel: () => _cancelAction(context),
                    onApply: (transformation) => _applyAction(context),
                  );
                case null:
                  return Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...actions.map(
                            (action) => Padding(
                              padding: const EdgeInsetsDirectional.only(start: padding),
                              child: OverlayButton(
                                child: IconButton(
                                  icon: action.getIcon(),
                                  onPressed: () => actionNotifier.value = action,
                                  tooltip: action.getText(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: padding),
                      Row(
                        children: [
                          const OverlayButton(
                            child: CloseButton(),
                          ),
                          const Spacer(),
                          OverlayTextButton(
                            onPressed: () {},
                            child: Text(context.l10n.saveCopyButtonLabel),
                          ),
                        ],
                      ),
                    ],
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  void _cancelAction(BuildContext context) {
    actionNotifier.value = null;
    context.read<TransformController>().reset();
  }

  void _applyAction(BuildContext context) {
    actionNotifier.value = null;
    context.read<TransformController>().reset();
  }
}
