import 'dart:math';

import 'package:aves/model/image_entry.dart';
import 'package:aves/model/settings.dart';
import 'package:aves/widgets/common/fx/sweeper.dart';
import 'package:aves/widgets/common/menu_row.dart';
import 'package:aves/widgets/fullscreen/fullscreen_actions.dart';
import 'package:aves/widgets/fullscreen/overlay/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:provider/provider.dart';

class FullscreenTopOverlay extends StatelessWidget {
  final List<ImageEntry> entries;
  final int index;
  final Animation<double> scale;
  final EdgeInsets viewInsets, viewPadding;
  final Function(FullscreenAction value) onActionSelected;
  final bool canToggleFavourite;

  ImageEntry get entry => entries[index];

  static const double padding = 8;

  static const int landscapeActionCount = 3;

  static const int portraitActionCount = 2;

  static const List<FullscreenAction> possibleOverlayActions = FullscreenActions.inApp;

  const FullscreenTopOverlay({
    Key key,
    @required this.entries,
    @required this.index,
    @required this.scale,
    this.canToggleFavourite = false,
    this.viewInsets,
    this.viewPadding,
    this.onActionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: (viewInsets ?? EdgeInsets.zero) + (viewPadding ?? EdgeInsets.zero),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Selector<MediaQueryData, Orientation>(
          selector: (c, mq) => mq.orientation,
          builder: (c, orientation, child) {
            final targetCount = orientation == Orientation.landscape ? landscapeActionCount : portraitActionCount;
            return LayoutBuilder(
              builder: (context, constraints) {
                final availableCount = (constraints.maxWidth / (kMinInteractiveDimension + padding)).floor() - 2;
                final recentActionCount = min(targetCount, availableCount);

                final recentActions = settings.mostRecentFullscreenActions.where(_canDo).take(recentActionCount);
                final inAppActions = FullscreenActions.inApp.where((action) => !recentActions.contains(action)).where(_canDo);
                final externalAppActions = FullscreenActions.externalApp.where(_canDo);

                return Row(
                  children: [
                    OverlayButton(
                      scale: scale,
                      child: ModalRoute.of(context)?.canPop ?? true ? const BackButton() : const CloseButton(),
                    ),
                    const Spacer(),
                    ...recentActions.map(_buildOverlayButton),
                    OverlayButton(
                      scale: scale,
                      child: PopupMenuButton<FullscreenAction>(
                        itemBuilder: (context) => [
                          ...inAppActions.map(_buildPopupMenuItem),
                          const PopupMenuDivider(),
                          ...externalAppActions.map(_buildPopupMenuItem),
                        ],
                        onSelected: (action) {
                          if (possibleOverlayActions.contains(action)) {
                            settings.mostRecentFullscreenActions = [action, ...settings.mostRecentFullscreenActions].take(landscapeActionCount).toList();
                          }
                          onActionSelected?.call(action);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _canDo(FullscreenAction action) {
    switch (action) {
      case FullscreenAction.toggleFavourite:
        return canToggleFavourite;
      case FullscreenAction.delete:
      case FullscreenAction.rename:
        return entry.canEdit;
      case FullscreenAction.rotateCCW:
      case FullscreenAction.rotateCW:
        return entry.canRotate;
      case FullscreenAction.print:
        return entry.canPrint;
      case FullscreenAction.openMap:
        return entry.hasGps;
      case FullscreenAction.share:
      case FullscreenAction.info:
      case FullscreenAction.open:
      case FullscreenAction.edit:
      case FullscreenAction.setAs:
        return true;
    }
    return false;
  }

  Widget _buildOverlayButton(FullscreenAction action) {
    Widget child;
    final onPressed = () => onActionSelected?.call(action);
    switch (action) {
      case FullscreenAction.toggleFavourite:
        child = ValueListenableBuilder<bool>(
          valueListenable: entry.isFavouriteNotifier,
          builder: (context, isFavourite, child) => Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(isFavourite ? OMIcons.favorite : OMIcons.favoriteBorder),
                onPressed: onPressed,
                tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
              ),
              Sweeper(
                builder: (context) => Icon(OMIcons.favoriteBorder, color: Colors.redAccent),
                toggledNotifier: entry.isFavouriteNotifier,
              ),
            ],
          ),
        );
        break;
      case FullscreenAction.info:
      case FullscreenAction.share:
      case FullscreenAction.delete:
      case FullscreenAction.rename:
      case FullscreenAction.rotateCCW:
      case FullscreenAction.rotateCW:
      case FullscreenAction.print:
        final textIcon = FullscreenActions.getTextIcon(action);
        child = IconButton(
          icon: Icon(textIcon.item2),
          onPressed: onPressed,
          tooltip: textIcon.item1,
        );
        break;
      case FullscreenAction.openMap:
      case FullscreenAction.open:
      case FullscreenAction.edit:
      case FullscreenAction.setAs:
        break;
    }
    return child != null
        ? Padding(
            padding: const EdgeInsetsDirectional.only(end: padding),
            child: OverlayButton(
              scale: scale,
              child: child,
            ),
          )
        : const SizedBox.shrink();
  }

  PopupMenuEntry<FullscreenAction> _buildPopupMenuItem(FullscreenAction action) {
    Widget child;
    switch (action) {
      // in app actions
      case FullscreenAction.toggleFavourite:
        child = entry.isFavouriteNotifier.value
            ? const MenuRow(
                text: 'Remove from favourites',
                icon: OMIcons.favorite,
              )
            : const MenuRow(
                text: 'Add to favourites',
                icon: OMIcons.favoriteBorder,
              );
        break;
      case FullscreenAction.info:
      case FullscreenAction.share:
      case FullscreenAction.delete:
      case FullscreenAction.rename:
      case FullscreenAction.rotateCCW:
      case FullscreenAction.rotateCW:
      case FullscreenAction.print:
        final textIcon = FullscreenActions.getTextIcon(action);
        child = MenuRow(text: textIcon.item1, icon: textIcon.item2);
        break;
      // external app actions
      case FullscreenAction.edit:
      case FullscreenAction.open:
      case FullscreenAction.setAs:
      case FullscreenAction.openMap:
        final textIcon = FullscreenActions.getTextIcon(action);
        child = Text(textIcon.item1);
        break;
    }
    return PopupMenuItem(
      value: action,
      child: child,
    );
  }
}
