import 'package:flutter/material.dart';

enum ShellLayout { compact, rail, expanded }

abstract final class Breakpoints {
  static const double compact = 780;
  static const double rail = 1180;
  static const double compactDrawerWidth = 264;
  static const double railWidth = 76;
  static const double sidebarWidth = 258;
  static const double topBarHeight = 56;
  static const double pageMaxWidth = 1440;
}

extension ShellLayoutX on BuildContext {
  ShellLayout get shellLayout {
    final double width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.compact) {
      return ShellLayout.compact;
    }
    if (width < Breakpoints.rail) {
      return ShellLayout.rail;
    }
    return ShellLayout.expanded;
  }

  bool get isCompact => shellLayout == ShellLayout.compact;
}
