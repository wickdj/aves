import 'dart:async';

import 'package:aves/model/entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:streams_channel/streams_channel.dart';

abstract class MediaStoreService {
  Future<List<int>> checkObsoleteContentIds(List<int> knownContentIds);

  Future<List<int>> checkObsoletePaths(Map<int, String> knownPathById);

  // knownEntries: map of contentId -> dateModifiedSecs
  Stream<AvesEntry> getEntries(Map<int, int> knownEntries);
}

class PlatformMediaStoreService implements MediaStoreService {
  static const platform = MethodChannel('deckers.thibault/aves/mediastore');
  static final StreamsChannel _streamChannel = StreamsChannel('deckers.thibault/aves/mediastorestream');

  @override
  Future<List<int>> checkObsoleteContentIds(List<int> knownContentIds) async {
    try {
      final result = await platform.invokeMethod('checkObsoleteContentIds', <String, dynamic>{
        'knownContentIds': knownContentIds,
      });
      return (result as List).cast<int>();
    } on PlatformException catch (e) {
      debugPrint('checkObsoleteContentIds failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return [];
  }

  @override
  Future<List<int>> checkObsoletePaths(Map<int, String> knownPathById) async {
    try {
      final result = await platform.invokeMethod('checkObsoletePaths', <String, dynamic>{
        'knownPathById': knownPathById,
      });
      return (result as List).cast<int>();
    } on PlatformException catch (e) {
      debugPrint('checkObsoletePaths failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return [];
  }

  @override
  Stream<AvesEntry> getEntries(Map<int, int> knownEntries) {
    try {
      return _streamChannel.receiveBroadcastStream(<String, dynamic>{
        'knownEntries': knownEntries,
      }).map((event) => AvesEntry.fromMap(event));
    } on PlatformException catch (e) {
      debugPrint('getEntries failed with code=${e.code}, exception=${e.message}, details=${e.details}');
      return Stream.error(e);
    }
  }
}