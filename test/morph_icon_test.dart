import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/widgets/morph_icon.dart';

void main() {
  test('Flutter polar geometry matches the real npm morphicons engine, including overshoot', () {
    final fixtures = jsonDecode(
      File('test/fixtures/morphicons_reference.json').readAsStringSync(),
    ) as Map;
    for (final entry in fixtures.entries) {
      final names = (entry.key as String).split(':');
      final plan = MorphPlan.find(
        AppGlyph.values.byName(names[0]),
        AppGlyph.values.byName(names[1]),
      )!;
      final buffers = plan.allocate();
      for (final frame in entry.value as List) {
        plan.writePoints((frame['t'] as num).toDouble(), buffers);
        final expected = frame['points'] as List;
        expect(buffers.length, expected.length);
        for (var k = 0; k < buffers.length; k++) {
          for (var i = 0; i < buffers[k].length; i++) {
            expect(
              buffers[k][i],
              closeTo((expected[k][i] as num).toDouble(), 0.000002),
              reason: '${entry.key}, t=${frame['t']}, contour=$k, point=$i',
            );
          }
        }
      }
    }
  });
  testWidgets('Every bundled vector renders without Material icon fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [for (final glyph in AppGlyph.values) MorphIcon(glyph)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MorphIcon), findsNWidgets(AppGlyph.values.length));
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Rapid reverse morphs are interruptible and settle', (
    tester,
  ) async {
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, value, _) => Center(
            child: MorphIcon(
              AppGlyph.radar,
              alternate: AppGlyph.activity,
              active: value,
              size: 48,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    active.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    active.value = true;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reduced motion suppresses stroke drawing and spring tickers', (
    tester,
  ) async {
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, value, _) => MorphIcon(
            AppGlyph.play,
            alternate: AppGlyph.pause,
            active: value,
          ),
        ),
      ),
    );
    active.value = true;
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Icon size is preserved inside large parent and input decoration',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: MorphIcon(
                    AppGlyph.heart,
                    key: Key('brandIcon'),
                    size: 28,
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: MorphIcon(
                      AppGlyph.user,
                      key: Key('inputIcon'),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(const Key('brandIcon')),
            matching: find.byType(CustomPaint),
          ),
        ),
        const Size(28, 28),
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(const Key('inputIcon')),
            matching: find.byType(CustomPaint),
          ),
        ),
        const Size(24, 24),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
