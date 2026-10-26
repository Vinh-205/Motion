import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_safety_bridge.dart';

class AppAppearance extends ValueNotifier<ThemeMode> {
  AppAppearance() : super(ThemeMode.light);
  int _revision = 0;
  bool _closed = false;
  bool get isDark => value == ThemeMode.dark;
  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await DeviceSafetyBridge.channel.invokeMethod<String>(
        'getAppearance',
      );
      if (!_closed && revision == _revision) {
        value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
    } on MissingPluginException {
      /* Use the light default outside Android. */
    } on PlatformException {
      /* Appearance does not affect monitoring. */
    }
  }

  Future<void> toggle() async {
    _revision++;
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    try {
      await DeviceSafetyBridge.channel.invokeMethod<void>('setAppearance', {
        'mode': isDark ? 'dark' : 'light',
      });
    } on MissingPluginException {
      /* Keep the selected appearance for this session. */
    } on PlatformException {
      /* Keep the selected appearance for this session. */
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppAppearance> {
  const AppearanceScope({
    super.key,
    required AppAppearance appearance,
    required super.child,
  }) : super(notifier: appearance);
  static AppAppearance? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
