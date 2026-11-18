import 'package:flutter/material.dart';

/// Architectural shape tokens for Concept A.
///
/// Physical paper sheets stay sharp (3dp–4dp) while interactive CTAs use
/// refined pills (999dp) and inputs/folios use restrained geometry (10dp–14dp).
abstract final class ScaneliqRadius {
  static const double sheet = 3.0;
  static const double paper = 4.0;
  static const double tag = 4.0;
  static const double brandMark = 7.0;
  static const double input = 10.0;
  static const double button = 12.0;
  static const double folio = 14.0;
  static const double modalTop = 22.0;
  static const double pill = 999.0;

  static final BorderRadius sheetBorderRadius = BorderRadius.circular(sheet);
  static final BorderRadius paperBorderRadius = BorderRadius.circular(paper);
  static final BorderRadius tagBorderRadius = BorderRadius.circular(tag);
  static final BorderRadius brandMarkBorderRadius = BorderRadius.circular(
    brandMark,
  );
  static final BorderRadius inputBorderRadius = BorderRadius.circular(input);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(button);
  static final BorderRadius folioBorderRadius = BorderRadius.circular(folio);
  static const BorderRadius modalSheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(modalTop),
  );
  static final BorderRadius pillBorderRadius = BorderRadius.circular(pill);
}
