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
}
