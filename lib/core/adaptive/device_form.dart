import 'dart:io';

import 'package:flutter/widgets.dart';

/// Four layout targets requested by product:
/// phone · tablet portrait · tablet landscape · TV.
enum DeviceForm {
  phone,
  tabletPortrait,
  tabletLandscape,
  tv;

  bool get isPhone => this == DeviceForm.phone;
  bool get isTablet =>
      this == DeviceForm.tabletPortrait || this == DeviceForm.tabletLandscape;
  bool get isTabletPortrait => this == DeviceForm.tabletPortrait;
  bool get isTabletLandscape => this == DeviceForm.tabletLandscape;
  bool get isTv => this == DeviceForm.tv;
  bool get prefersSideNav => isTabletLandscape || isTv;
  bool get prefersTopTabs => isTabletPortrait;
  bool get prefersBottomDock => isPhone;
  bool get usesLargeFocus => isTv;
}

class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({super.key, required this.form, required super.child});

  final DeviceForm form;

  static DeviceForm of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdaptiveScope>();
    return scope?.form ?? DeviceForm.phone;
  }

  @override
  bool updateShouldNotify(AdaptiveScope oldWidget) => form != oldWidget.form;
}

/// Detects the layout form from size + platform.
DeviceForm resolveDeviceForm(BuildContext context) {
  if (_isTelevision()) return DeviceForm.tv;

  final size = MediaQuery.sizeOf(context);
  final shortest = size.shortestSide;
  final isLandscape = size.width >= size.height;

  if (shortest < 600) return DeviceForm.phone;
  return isLandscape ? DeviceForm.tabletLandscape : DeviceForm.tabletPortrait;
}

bool _isTelevision() {
  if (Platform.isAndroid) {
    // Android TV / Google TV ship with leanback features; uiMode is checked
    // lightly here via environment to avoid a platform channel in pure Dart.
    final uiMode = Platform.environment['UI_MODE'] ?? '';
    if (uiMode.contains('television')) return true;
  }
  // Explicit override for emulators / iPad-as-TV layouts.
  return const bool.fromEnvironment('FROG_TV', defaultValue: false);
}

/// Scale multipliers for density and focus chrome.
extension DeviceFormX on DeviceForm {
  double get posterScale => switch (this) {
        DeviceForm.phone => 1,
        DeviceForm.tabletPortrait => 1.15,
        DeviceForm.tabletLandscape => 1.2,
        DeviceForm.tv => 1.5,
      };

  double get typeScale => switch (this) {
        DeviceForm.phone => 1,
        DeviceForm.tabletPortrait => 1.05,
        DeviceForm.tabletLandscape => 1.08,
        DeviceForm.tv => 1.25,
      };

  double get contentMaxWidth => switch (this) {
        DeviceForm.phone => double.infinity,
        DeviceForm.tabletPortrait => 720,
        DeviceForm.tabletLandscape => 1100,
        DeviceForm.tv => 1280,
      };

  int get overviewCrossAxisCount => switch (this) {
        DeviceForm.phone => 3,
        DeviceForm.tabletPortrait => 4,
        DeviceForm.tabletLandscape => 6,
        DeviceForm.tv => 6,
      };
}
