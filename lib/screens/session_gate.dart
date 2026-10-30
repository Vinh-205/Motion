import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/motion_api.dart';
import '../widgets/startup_animation.dart';
import 'account_screen.dart';
import 'alert_screen.dart';
import 'cloud_dashboard_screen.dart';
import 'home_screen.dart';

/// Authentication guards normal navigation, never the time-critical SOS screen.
/// This owner remains alive across login/logout so cloud state cannot stop SOS.
class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    this.api,
    this.controller,
    this.showLaunchAnimation = false,
    this.startupPresentation,
  });
  final MotionApi? api;
  final AppController? controller;
  final bool showLaunchAnimation;
  final Future<void>? startupPresentation;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> with WidgetsBindingObserver {
  late final MotionApi api = widget.api ?? MotionApi();
  late final AppController controller = widget.controller ?? AppController();
  late bool launching = widget.showLaunchAnimation;
  bool emergency = false, monitorOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    api.addListener(_sessionChanged);
    controller.addListener(_safetyChanged);
    controller.start();
    emergency = controller.alertActive || controller.sosActive;
    if (!api.restored) api.restore();
  }

  void _returnToRoot() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  });
  void _sessionChanged() {
    if (!mounted) return;
    if (!api.signedIn) {
      monitorOpen = false;
      _returnToRoot();
    }
    setState(() {});
  }

  void _safetyChanged() {
    final active = controller.alertActive || controller.sosActive;
    if (active == emergency || !mounted) return;
    setState(() {
      emergency = active;
      if (active) launching = false;
    });
    if (active) _returnToRoot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      controller.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api.removeListener(_sessionChanged);
    controller.removeListener(_safetyChanged);
    controller.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (emergency) return AlertScreen(controller: controller);
    if (launching) {
      return StartupAnimation(
        presentationReady: widget.startupPresentation,
        onFinished: () {
          if (mounted) setState(() => launching = false);
        },
      );
    }
    if (!api.restored || !api.signedIn) {
      return AccountScreen(api: api, controller: controller);
    }
    if (api.role != 'member' && !monitorOpen) {
      return CloudDashboardScreen(
        api: api,
        controller: controller,
        onOpenMonitor: () => setState(() => monitorOpen = true),
      );
    }
    return HomeScreen(
      controller: controller,
      cloudApi: api,
      manageController: false,
    );
  }
}
