import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_controller.dart';
import '../services/motion_api.dart';
import '../services/app_appearance.dart';
import '../widgets/app_design.dart';
import 'monitor_screen.dart';
import 'history_screen.dart';
import 'contact_screen.dart';
import 'settings_screen.dart';
import 'alert_screen.dart';
import 'account_screen.dart';
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
        SettingsScreen(controller: _controller),
      ];
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: context.colors.lime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: MorphIcon(
                            AppGlyph.orbit,
                            alternate: AppGlyph.radar,
                            active: _controller.realSmsEnabled,
                            color: context.colors.background,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'MOTION',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 17,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w800,
                            color: context.colors.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (AppearanceScope.of(context) case final appearance?)
                          IconButton(
                            key: const Key('toggleAppearance'),
                            tooltip: appearance.isDark
                                ? 'Chuyển sang giao diện sáng'
                                : 'Chuyển sang giao diện tối',
                            onPressed: appearance.toggle,
                            icon: MorphIcon(
                              AppGlyph.sun,
                              alternate: AppGlyph.moon,
                              active: appearance.isDark,
                              size: 22,
                              color: context.colors.ink,
                            ),
                          ),
                        IconButton(
                          key: const Key('openCloudAccount'),
                          tooltip: 'Tài khoản / Vòng an toàn',
                          icon: const MorphIcon(AppGlyph.user, size: 22),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => AccountScreen(
                                controller: _controller,
                                api: widget.cloudApi,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: context.colors.line,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  _controller.realSmsEnabled
                                      ? 'SMS QUA SIM'
                                      : _controller.canSimulate
                                      ? 'KIỂM THỬ'
                                      : 'CHƯA BẬT SOS',
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    color: context.colors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              child: _MotionNavigation(index: _index, onChanged: _select),
            ),
          ),
        ),
      );
    },
  );
}

class _MotionNavigation extends StatelessWidget {
  const _MotionNavigation({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['Theo dõi', 'Lịch sử', 'Liên hệ', 'Cài đặt'];
  static const icons = [
    AppGlyph.radar,
    AppGlyph.timeline,
    AppGlyph.users,
    AppGlyph.sliders,
  ];
  static const activeIcons = [
    AppGlyph.activity,
    AppGlyph.history,
    AppGlyph.contact,
    AppGlyph.settings,
  ];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: context.colors.line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          AnimatedPositioned(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            left: constraints.maxWidth / 4 * index,
            top: 0,
            bottom: 0,
            width: constraints.maxWidth / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.lime,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: labels[i],
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onChanged(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 3,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedRotation(
                                turns: 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 350),
                                child: MorphIcon(
                                  icons[i],
                                  alternate: activeIcons[i],
                                  active: i == index,
                                  size: 23,
                                  color: i == index
                                      ? context.colors.background
                                      : context.colors.muted,
                                ),
                              ),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: i == index
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: i == index
                                        ? context.colors.background
                                        : context.colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
