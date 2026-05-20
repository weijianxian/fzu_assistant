import 'package:flutter/widgets.dart';

extension OrientationX on BuildContext {
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
}
