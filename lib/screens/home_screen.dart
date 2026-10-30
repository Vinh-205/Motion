import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_controller.dart';
import '../services/motion_api.dart';
import 'monitor_screen.dart';
import 'history_screen.dart';
import 'contact_screen.dart';
import 'settings_screen.dart';
import 'alert_screen.dart';
import '../widgets/motion_header.dart';
import '../widgets/liquid_navigation.dart';
import '../widgets/startup_animation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.showLaunchAnimation = false,
    this.startupPresentation,
    this.cloudApi,
    this.manageController = true,
  });
  final AppController? controller;
  final bool showLaunchAnimation;
  final Future<void>? startupPresentation;
  final MotionApi? cloudApi;
  final bool manageController;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AppController _controller;
  late final AnimationController _entrance;
  late final CurvedAnimation _entranceCurve;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  int _index = 0;
  late bool _showLaunchAnimation = widget.showLaunchAnimation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? AppController();
    _controller.addListener(_revealAlert);
    if (widget.manageController) _controller.start();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1,
    );
    _entranceCurve = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0.25, end: 1).animate(_entranceCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(_entranceCurve);
  }

  bool _revealingAlert = false;
  void _revealAlert() {
    if (!_controller.alertActive && !_controller.sosActive) {
      _revealingAlert = false;
      return;
    }
    if (_revealingAlert) return;
    _revealingAlert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_controller.alertActive || _controller.sosActive)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _controller.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceCurve.dispose();
    _entrance.dispose();
    _controller.removeListener(_revealAlert);
    if (widget.manageController) _controller.dispose();
    super.dispose();
  }

  void _select(int value) {
    if (_index == value) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _index = value);
    if (!MediaQuery.disableAnimationsOf(context)) _entrance.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (_controller.alertActive || _controller.sosActive) {
        _showLaunchAnimation = false;
        return AlertScreen(controller: _controller);
      }
      if (_showLaunchAnimation) {
        return StartupAnimation(
          presentationReady: widget.startupPresentation,
          onFinished: () {
            if (mounted) setState(() => _showLaunchAnimation = false);
          },
        );
      }
      final pages = [
        MonitorScreen(controller: _controller),
        HistoryScreen(controller: _controller),
        ContactScreen(controller: _controller),
        SettingsScreen(controller: _controller, cloudApi: widget.cloudApi),
      ];
      return Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  MotionHeader(controller: _controller),
                  Expanded(
                    child: FadeTransition(
                      opacity: _opacity,
                      child: SlideTransition(
                        position: _slide,
                        child: IndexedStack(
                          index: _index,
                          children: [
                            for (var i = 0; i < pages.length; i++)
                              TickerMode(enabled: _index == i, child: pages[i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 632),
              child: LiquidNavigation(index: _index, onChanged: _select),
            ),
          ),
        ),
      );
    },
  );
}
