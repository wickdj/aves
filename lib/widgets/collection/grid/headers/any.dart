import 'dart:math';

import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/enums.dart';
import 'package:aves/model/source/section_keys.dart';
import 'package:aves/widgets/collection/grid/headers/album.dart';
import 'package:aves/widgets/collection/grid/headers/date.dart';
import 'package:aves/widgets/common/grid/header.dart';
import 'package:flutter/material.dart';

class CollectionSectionHeader extends StatelessWidget {
  final CollectionLens collection;
  final SectionKey sectionKey;
  final double height;

  const CollectionSectionHeader({
    Key key,
    @required this.collection,
    @required this.sectionKey,
    @required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final header = _buildHeader();
    return header != null
        ? SizedBox(
            height: height,
            child: header,
          )
        : SizedBox.shrink();
  }

  Widget _buildHeader() {
    Widget _buildAlbumHeader() => AlbumSectionHeader(
          key: ValueKey(sectionKey),
          source: collection.source,
          folderPath: (sectionKey as EntryAlbumSectionKey).folderPath,
        );

    switch (collection.sortFactor) {
      case EntrySortFactor.date:
        switch (collection.groupFactor) {
          case EntryGroupFactor.album:
            return _buildAlbumHeader();
          case EntryGroupFactor.month:
            return MonthSectionHeader(key: ValueKey(sectionKey), date: (sectionKey as EntryDateSectionKey).date);
          case EntryGroupFactor.day:
            return DaySectionHeader(key: ValueKey(sectionKey), date: (sectionKey as EntryDateSectionKey).date);
          case EntryGroupFactor.none:
            break;
        }
        break;
      case EntrySortFactor.name:
        return _buildAlbumHeader();
      case EntrySortFactor.size:
        break;
    }
    return null;
  }

  static double getPreferredHeight(BuildContext context, double maxWidth, CollectionSource source, SectionKey sectionKey) {
    var headerExtent = 0.0;
    if (sectionKey is EntryAlbumSectionKey) {
      // only compute height for album headers, as they're the only likely ones to split on multiple lines
      headerExtent = AlbumSectionHeader.getPreferredHeight(context, maxWidth, source, sectionKey);
    }

    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    headerExtent = max(headerExtent, SectionHeader.leadingDimension * textScaleFactor) + SectionHeader.padding.vertical;
    return headerExtent;
  }
}