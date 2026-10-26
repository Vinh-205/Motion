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
      expect(
        await bridge.saveContacts([
          {'id': 'dry-a', 'name': 'Kiểm thử A', 'phone': '0900000001'},
          {'id': 'dry-b', 'name': 'Kiểm thử B', 'phone': '0900000002'},
        ]),
        true,
      );
      await bridge.command('configure', {'countdownSeconds': 15});
      final started = await bridge.command('startBackgroundDryRun');
      expect(started['running'], true);
      expect(started['dryRun'], true);
      expect(started['enabled'], false);
      final pending = await bridge.command('triggerDryRunAlert', {
        'autoCallDryRun': true,
      });
      expect(pending['pending'], true);
      final id = pending['currentId'];
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
      await bridge.command('triggerDryRunAlert');
      final repeated = (await bridge.state())!;
      expect(
        (repeated['events'] as List).where((e) => e['id'] == id).length,
        1,
      );
      debugPrint('MOTION_NATIVE_DRY_RUN_COMPLETED_WITHOUT_SMS');
    } finally {
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
      });
    }
  });
}
