import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/services/audio_player.dart';
import 'package:quran_memorization/main.dart';
import 'package:quran_memorization/memorization_calc.dart'
    show MemorizationDirection;
import 'package:quran_memorization/screens/page_viewer_screen.dart';
import 'package:quran_memorization/services/audio_unit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudio implements QuranAudio {
  final _completed = StreamController<void>();

  @override
  Future<void> play({required List<String> urls, required int repeat}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<void> get onCompleted => _completed.stream;
}

Future<AudioUnitController> startedUnit() async {
  final unit = AudioUnitController(audio: _FakeAudio());
  await unit.play(
    urls: const ['u1'],
    label: 'سورة البقرة · page 22',
    settings: 'Husary (murattal) · 1.5× · repeat ×3',
    page: 22,
    linesPerDay: 5,
    direction: MemorizationDirection.forward,
    repeat: 3,
    reciter: Reciter.husary,
    speed: 1.5,
    echo: false,
  );
  return unit;
}

void main() {
  testWidgets('planner shows a persistent mini player and toggles it', (
    tester,
  ) async {
    final unit = await startedUnit();
    await tester.pumpWidget(MaterialApp(home: PlannerScreen(unit: unit)));

    expect(find.byKey(const ValueKey('mini-player')), findsOneWidget);
    expect(find.text('سورة البقرة · page 22'), findsOneWidget);
    expect(find.text('Husary (murattal) · 1.5× · repeat ×3'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Pause from the mini player; the unit keeps its label.
    await tester.tap(find.byKey(const ValueKey('mini-play')));
    await tester.pump();
    expect(unit.playing, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(unit.hasUnit, isTrue);

    // Resume.
    await tester.tap(find.byKey(const ValueKey('mini-play')));
    await tester.pump();
    expect(unit.playing, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Dismiss.
    await tester.tap(find.byKey(const ValueKey('mini-close')));
    await tester.pump();
    expect(unit.hasUnit, isFalse);
    expect(find.byKey(const ValueKey('mini-player')), findsNothing);
  });

  testWidgets('no mini player without an active unit', (tester) async {
    final unit = AudioUnitController(audio: _FakeAudio());
    await tester.pumpWidget(MaterialApp(home: PlannerScreen(unit: unit)));
    expect(find.byKey(const ValueKey('mini-player')), findsNothing);
  });

  testWidgets('tapping the mini player reopens the mushaf viewer', (
    tester,
  ) async {
    final unit = await startedUnit();
    await tester.pumpWidget(MaterialApp(home: PlannerScreen(unit: unit)));

    await tester.tap(find.byKey(const ValueKey('mini-player')));
    await tester.pump(); // frame for the tap
    await tester.pump(); // build the pushed route
    expect(find.byType(PageViewerScreen), findsOneWidget);
    // The reopened viewer lands on the unit's page and inherits its settings.
    expect(find.text('Page 22'), findsOneWidget);

    // Back on the planner the mini player is still there, still playing.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mini-player')), findsOneWidget);
    expect(unit.playing, isTrue);
  });
  testWidgets('mini player shows live reciter and speed changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final unit = await startedUnit();  // snapshot: Husary · 1.5x · x3
    await tester.pumpWidget(MaterialApp(home: PlannerScreen(unit: unit)));
    expect(find.text('Husary (murattal) · 1.5× · repeat ×3'), findsOneWidget);

    // Change speed and reciter on the shared unit while the planner is up.
    await unit.setSpeed(0.75);
    await unit.saveDefaults(reciter: Reciter.sudais);
    await tester.pump();

    // The bar now shows the live values, not the start-time snapshot.
    expect(find.text('Husary (murattal) · 1.5× · repeat ×3'), findsNothing);
    expect(find.text('Sudais · 0.75× · repeat ×3'), findsOneWidget);

    // Echo toggles live too.
    await unit.setEcho(true);
    await tester.pump();
    expect(find.text('Sudais · 0.75× · repeat ×3 · echo'), findsOneWidget);
  });
  testWidgets('nightly review button opens the viewer in review mode', (
    tester,
  ) async {
    final unit = AudioUnitController(audio: _FakeAudio());
    await tester.pumpWidget(MaterialApp(home: PlannerScreen(unit: unit)));
    await tester.pump(); // settle the first frame (cursor blinks prevent settle)

    await tester.tap(find.byIcon(Icons.nightlight_outlined));
    await tester.pump(); // frame for the tap
    await tester.pump(); // build the pushed route
    expect(find.byType(PageViewerScreen), findsOneWidget);
    // Default planner (page 1, 10 lines/day) -> the review window starts at
    // page 1, so the viewer opens there in review mode.
    expect(find.text('Page 1'), findsOneWidget);
  });
}
