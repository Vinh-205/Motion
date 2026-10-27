import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_safety_bridge.dart';
import 'app_design.dart';
import 'morph_icon.dart';

class AlertSoundSettings extends StatefulWidget {
  const AlertSoundSettings({super.key, required this.device});
  final DeviceSafetyBridge device;
  @override
  State<AlertSoundSettings> createState() => _AlertSoundSettingsState();
}

class _AlertSoundSettingsState extends State<AlertSoundSettings>
    with WidgetsBindingObserver {
  String _title = 'Chuông SOS Motion · mặc định';
  String? _error;
  bool _busy = false, _previewing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final settings = await widget.device.alertSound();
      if (mounted && settings != null) {
        setState(() => _title = settings['title'] as String? ?? _title);
      }
    } catch (_) {
      /* The default remains available on an older APK. */
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    if (!_previewing) return;
    _previewing = false;
    try {
      await widget.device.previewAlertSound(false);
    } catch (_) {
      /* Native countdown audio has priority. */
    }
    if (mounted) setState(() {});
  }

  Future<void> _act({required bool pick}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (pick) {
        await _stop();
        final settings = await widget.device.alertSound(pick: true);
        if (mounted && settings != null) {
          setState(() => _title = settings['title'] as String? ?? _title);
        }
      } else if (_previewing) {
        await _stop();
      } else {
        await widget.device.previewAlertSound(true);
        if (mounted) {
          _previewing = true;
          _timer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _previewing = false);
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) _error = e.message ?? 'Không mở được âm thanh.';
    } on MissingPluginException {
      if (mounted) {
        _error = 'Hãy dừng và chạy lại app để cài phần âm thanh mới.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_previewing) {
      unawaited(
        widget.device.previewAlertSound(false).catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MorphIcon(
              AppGlyph.bell,
              alternate: AppGlyph.bellRing,
              active: _previewing,
              color: context.colors.lime,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _title,
                key: const Key('selectedAlertSound'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            TextButton(
              key: const Key('chooseAlertSound'),
              onPressed: _busy ? null : () => _act(pick: true),
              child: const Text('CHỌN ÂM THANH'),
            ),
            TextButton(
              key: const Key('defaultAlertSound'),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await _stop();
                        final result = await widget.device.command(
                          'resetAlertSound',
                        );
                        if (mounted) {
                          setState(() {
                            _title =
                                result['title'] as String? ??
                                'Chuông SOS Motion · mặc định';
                            _error = null;
                          });
                        }
                      } on PlatformException catch (e) {
                        if (mounted) setState(() => _error = e.message);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('DÙNG CHUÔNG SOS MOTION'),
            ),
            TextButton(
              key: const Key('previewAlertSound'),
              onPressed: _busy ? null : () => _act(pick: false),
              child: Text(_previewing ? 'DỪNG NGHE THỬ' : 'NGHE THỬ · 3 GIÂY'),
            ),
          ],
        ),
        Text(
          'Dùng cho cảnh báo té ngã và SOS. Âm lượng theo mức báo thức của điện thoại. Nghe thử không gửi SMS.',
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: context.colors.orange),
            ),
          ),
      ],
    ),
  );
}
