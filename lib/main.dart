import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/session_gate.dart';
import 'widgets/app_design.dart';
import 'services/app_appearance.dart';
import 'services/app_controller.dart';
import 'services/motion_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('THIRD_PARTY_NOTICES.md');
    yield LicenseEntryWithLineBreaks(['morphicons', 'lucide'], notice);
  });
  final skip =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
      '/motion-alert';
  runApp(MyApp(showLaunchAnimation: !skip));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.appearance,
    this.controller,
    this.api,
    this.showLaunchAnimation = false,
    this.startupPresentation,
  });
  final AppAppearance? appearance;
  final AppController? controller;
  final MotionApi? api;
  final bool showLaunchAnimation;
  final Future<void>? startupPresentation;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppAppearance _appearance =
      widget.appearance ?? (AppAppearance()..load());
  @override
  void dispose() {
    if (widget.appearance == null) _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
    appearance: _appearance,
    child: ListenableBuilder(
      listenable: _appearance,
      builder: (context, _) => MaterialApp(
        title: 'Motion',
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(),
        themeMode: _appearance.value,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: context.colors.background,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child!,
        ),
        home: SessionGate(
          api: widget.api,
          controller: widget.controller,
          showLaunchAnimation: widget.showLaunchAnimation,
          startupPresentation: widget.startupPresentation,
        ),
      ),
    ),
  );
}
