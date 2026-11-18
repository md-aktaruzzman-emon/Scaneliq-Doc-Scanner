/// 4-point spatial rhythm and layout constants for Concept A.
abstract final class ScaneliqSpacing {
  static const double unit = 4.0;

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Layout gutters and structural metrics
  static const double screenHorizontal = 24.0;
  static const double screenHorizontalCompact = 16.0;
  static const double headerVerticalTop = 12.0;
  static const double headerVerticalBottom = 14.0;
  static const double searchZoneBottom = 14.0;
  static const double sectionGap = 16.0;
  static const double listRowVertical = 12.0;
  static const double listRowGap = 15.0;
  static const double bottomNavHeight = 68.0;
  static const double fabClusterBottomGap = 16.0;
  static const double minTouchTarget = 40.0;
  static const double a11yTouchTarget = 48.0;

  /// Adapts horizontal gutter cleanly on ultra-compact screens (<360dp).
  static double adaptiveHorizontalPadding(double width) {
    if (width < 360) return screenHorizontalCompact;
    if (width >= 700) return 32.0;
    return screenHorizontal;
  }
}
