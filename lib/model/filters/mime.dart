import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/image_entry.dart';
import 'package:aves/model/mime_types.dart';
import 'package:aves/widgets/common/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:outline_material_icons/outline_material_icons.dart';

class MimeFilter extends CollectionFilter {
  static const type = 'mime';

  // fake mime type
  static const animated = 'aves/animated'; // subset of `image/gif` and `image/webp`

  final String mime;
  bool Function(ImageEntry) _filter;
  String _label;
  IconData _icon;

  MimeFilter(this.mime) {
    var lowMime = mime.toLowerCase();
    if (mime == animated) {
      _filter = (entry) => entry.isAnimated;
      _label = 'Animated';
      _icon = AIcons.animated;
    } else if (lowMime.endsWith('/*')) {
      lowMime = lowMime.substring(0, lowMime.length - 2);
      _filter = (entry) => entry.mimeType.startsWith(lowMime);
      if (lowMime == 'video') {
        _label = 'Video';
        _icon = AIcons.video;
      }
      _label ??= lowMime.split('/')[0].toUpperCase();
    } else {
      _filter = (entry) => entry.mimeType == lowMime;
      if (lowMime == MimeTypes.SVG) {
        _label = 'SVG';
      }
      _label ??= lowMime.split('/')[1].toUpperCase();
    }
    _icon ??= OMIcons.code;
  }

  @override
  bool filter(ImageEntry entry) => _filter(entry);

  @override
  String get label => _label;

  @override
  Widget iconBuilder(context, size) => Icon(_icon, size: size);

  @override
  String get typeKey => type;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is MimeFilter && other.mime == mime;
  }

  @override
  int get hashCode => hashValues('MimeFilter', mime);
}