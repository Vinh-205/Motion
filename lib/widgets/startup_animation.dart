import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'app_design.dart';
import 'morph_icon.dart';

/// A brief brand introduction, never a readiness indicator or a blocker for SOS.
class StartupAnimation extends StatefulWidget {
  const StartupAnimation({
    super.key,
    required this.onFinished,
    this.presentationReady,
  });
  final VoidCallback onFinished;
  final Future<void>? presentationReady;
  @override
  State<StartupAnimation> createState() => _StartupAnimationState();
}

class _StartupAnimationState extends State<StartupAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1850),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  bool _finished = false;
  bool _waitingForPresentation = false;
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else if (!_waitingForPresentation && !_finished) {
      _waitingForPresentation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Do not consume the introduction while Android is still showing its
        // native splash or the GPU is rasterizing the first Flutter frame.
        await (widget.presentationReady ??
            WidgetsBinding.instance.waitUntilFirstFrameRasterized);
        if (mounted && !_finished && !MediaQuery.disableAnimationsOf(context)) {
          _motion.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('startupAnimation'),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final appear = Curves.easeOutCubic.transform(
                (_motion.value / .45).clamp(0.0, 1.0),
              );
              final exit = ((_motion.value - .86) / .14).clamp(0.0, 1.0);
              return Opacity(
                opacity: 1 - exit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ExcludeSemantics(
                            child: Lottie.asset(
                              'assets/animations/motion_startup.json',
                              controller: _motion,
                              repeat: false,
                              fit: BoxFit.contain,
                              delegates: LottieDelegates(
                                values: [
                                  ValueDelegate.color(const [
                                    '**',
                                  ], value: context.colors.lime),
                                ],
                              ),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          Transform.scale(
                            scale: .8 + .2 * appear,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: context.colors.lime,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: MorphIcon(
                                AppGlyph.orbit,
                                alternate: AppGlyph.radar,
                                active: _motion.value > .58,
                                size: 48,
                                color: context.colors.background,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Opacity(
                      opacity: appear,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - appear)),
                        child: Column(
                          children: [
                            Text(
                              'MOTION',
                              style: TextStyle(
                                color: context.colors.ink,
                                fontSize: 33,
                                letterSpacing: 7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Lắng nghe từng chuyển động.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.colors.muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
