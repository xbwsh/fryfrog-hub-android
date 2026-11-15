import 'package:flutter/widgets.dart';

/// Space occupied by the tablet's floating dock, including the system inset.
/// Apply it to scroll content so the viewport can extend behind the glass.
class FloatingDockInsets extends InheritedWidget {
  const FloatingDockInsets({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double? maybeBottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FloatingDockInsets>()?.bottom;

  @override
  bool updateShouldNotify(FloatingDockInsets oldWidget) =>
      bottom != oldWidget.bottom;
}
