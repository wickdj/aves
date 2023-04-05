import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

extension ExtraOffset on Offset {
  Vector3 get toVector3 => Vector3(dx, dy, 0);
}

extension ExtraVector3 on Vector3 {
  Offset get toOffset => Offset(x, y);
}
