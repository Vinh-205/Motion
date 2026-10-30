import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cam_bien_te_nga/services/device_safety_bridge.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';
import 'package:cam_bien_te_nga/widgets/morph_icon.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native foreground countdown completes in a no-SMS dry run', (
    tester,
  ) async {
    final bridge = DeviceSafetyBridge();
    final before = (await bridge.state())!;
    final originalCard =
        await DeviceSafetyBridge.channel.invokeMapMethod<String, dynamic>(
          'getEmergencyCard',
        ) ??
        {};
    expect(
      before['enabled'],
      false,
      reason: 'Run only with real SMS off. This test must not change an armed configuration.',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MorphIcon(AppGlyph.message, size: 64, color: AppColors.lime),
                SizedBox(height: 24),
                Text('KIỂM THỬ SOS NỀN'),
                Text('Không gửi SMS thật.'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await DeviceSafetyBridge.channel.invokeMethod<void>('saveEmergencyCard', {
        'name': 'Motion Test Wearer',
        'allergies': 'Synthetic test data',
        'showWhenLocked': true,
      });
      final savedCard = await DeviceSafetyBridge.channel
          .invokeMapMethod<String, dynamic>('getEmergencyCard');
      expect(savedCard?['name'], 'Motion Test Wearer');
      expect(
        await bridge.saveContacts([
          {'id': 'dry-a', 'name': 'Kiểm thử A', 'phone': '0900000001'},
          {'id': 'dry-b', 'name': 'Kiểm thử B', 'phone': '0900000002'},
        ]),
        true,
      );
      await bridge.command('configure', {
        'countdownSeconds': 15,
        'monitoring': true,
        'backgroundEnabled': true,
      });
      final started = await bridge.command('startBackgroundDryRun');
      expect(started['running'], true);
      expect(started['dryRun'], true);
      expect(started['enabled'], false);
      final pending = await bridge.command('triggerDryRunAlert', {
        'autoCallDryRun': true,
      });
      expect(pending['pending'], true);
      final id = pending['currentId'];
      // Turning off background collection does not stop foreground detection or
      // cancel a countdown. Exercise the real Activity onStop callback by going Home.
      final foregroundOnly = await bridge.command('configure', {
        'backgroundEnabled': false,
      });
      expect(foregroundOnly['monitoring'], true);
      expect(foregroundOnly['pending'], true);
      expect(foregroundOnly['sensorCollectionActive'], true);
      await bridge.command('leaveDryRunToHome');
      Map<String, dynamic> hidden = {};
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        hidden = (await bridge.state())!;
        if (hidden['appVisible'] == false) break;
      }
      expect(hidden['appVisible'], false);
      expect(hidden['sensorCollectionActive'], false);
      expect(hidden['nativeAcceleration'], isNull);
      expect(hidden['pending'], true);
      expect(hidden['currentId'], id);
      final resumedBackground = await bridge.command('configure', {
        'backgroundEnabled': true,
      });
      expect(resumedBackground['sensorCollectionActive'], true);
      final pausedBackground = await bridge.command('configure', {
        'backgroundEnabled': false,
      });
      expect(pausedBackground['sensorCollectionActive'], false);
      expect(pausedBackground['pending'], true);
      // Host runner opens the task like a user. Do not bypass Android background
      // activity restrictions from inside the app just to make a test pass.
      debugPrint('MOTION_DRY_RUN_READY_TO_RETURN');
      Map<String, dynamic> visibleAgain = {};
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        visibleAgain = (await bridge.state())!;
        if (visibleAgain['appVisible'] == true) break;
      }
      expect(visibleAgain['appVisible'], true);
      expect(visibleAgain['backgroundEnabled'], false);
      expect(visibleAgain['sensorCollectionActive'], true);
      expect(visibleAgain['pending'], true);
      // Editing setup must not change a pending alert's recipient snapshot.
      expect(
        await bridge.saveContacts([
          {'id': 'dry-c', 'name': 'Kiểm thử C', 'phone': '0900000003'},
        ]),
        true,
      );
      debugPrint('MOTION_NATIVE_DRY_RUN_COUNTDOWN_STARTED');
      // The host may lock the emulator during this interval. Native Android owns the deadline.
      await Future<void>.delayed(const Duration(seconds: 17));
      final complete = (await bridge.state())!;
      expect(complete['pending'], false);
      expect(complete['sosActive'], true);
      expect(complete['smsStatus'], 'dryRun');
      expect(complete['callStatus'], 'dryRun');
      expect(complete['callPermission'], before['callPermission']);
      expect(complete['autoCallEnabled'], before['autoCallEnabled']);
      expect(complete['enabled'], false);
      expect(complete['smsPermission'], before['smsPermission']);
      expect(
        (complete['events'] as List).where((e) => e['id'] == id).length,
        1,
      );
      final event =
          (complete['events'] as List).singleWhere((e) => e['id'] == id) as Map;
      final recipients = event['recipients'] as List;
      expect(event['callPhone'], '0900000001');
      expect(event['callStatus'], 'dryRun');
      expect(recipients.length, 2);
      expect(recipients.map((r) => r['phone']), ['0900000001', '0900000002']);
      expect(recipients.every((r) => r['smsStatus'] == 'dryRun'), true);
      debugPrint('MOTION_CARD_LOCKED_READ_READY');
      // The host taps the SOS notification as a user, then unlocks before cleanup.
      // Never start an Activity from a hidden Flutter engine to bypass Android BAL.
      await Future<void>.delayed(const Duration(seconds: 18));
      await bridge.command('triggerDryRunAlert');
      final repeated = (await bridge.state())!;
      expect(
        (repeated['events'] as List).where((e) => e['id'] == id).length,
        1,
      );
      debugPrint('MOTION_NATIVE_DRY_RUN_COMPLETED_WITHOUT_SMS');
    } finally {
      if (originalCard.isEmpty) {
        await DeviceSafetyBridge.channel.invokeMethod<void>(
          'deleteEmergencyCard',
        );
      } else {
        await DeviceSafetyBridge.channel.invokeMethod<void>(
          'saveEmergencyCard',
          originalCard,
        );
      }
      await bridge.command('disableRealSms');
      await bridge.saveContacts(
        ((before['contacts'] as List?) ?? [])
            .map((c) => Map<String, String>.from(c as Map))
            .toList(),
      );
      await bridge.command('configure', {
        'countdownSeconds': before['countdownSeconds'],
        'monitoring': before['monitoring'],
        'sensitivity': before['sensitivity'],
        'backgroundEnabled': before['backgroundEnabled'] ?? true,
      });
    }
  });
}
