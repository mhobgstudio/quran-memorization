import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/data/quran_text.dart';
import 'package:quran_memorization/screens/page_viewer_screen.dart';
import 'package:quran_memorization/services/audio_player.dart';

/// Minimal fixture modeled on the real asset schema: surah 1 (2 ayahs) on
/// page 1, surah 2 (3 ayahs) on page 2.
QuranText fixtureQuran() => QuranText.fromJson({
  'surahs': [
    {'s': 1, 'c': 2, 'n': 'الفاتحة', 't': 'Al-Faatiha'},
    {'s': 2, 'c': 3, 'n': 'البقرة', 't': 'Al-Baqara'},
  ],
  'text': ['أ', 'ب', 'ج', 'د', 'ه'],
  'pages': [
    [0, 1],
    [2, 3, 4],
  ],
});

class FakeQuranAudio implements QuranAudio {
  List<String>? playedUrls;
  int? repeat;
  bool paused = false;
  bool stopped = false;

  @override
  Future<void> play({required List<String> urls, required int repeat}) async {
    playedUrls = urls;
    this.repeat = repeat;
  }

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> dispose() async {}

  @override
  Stream<void> get onCompleted => const Stream<void>.empty();
}

Widget harness(int page, double linesPerDay, FakeQuranAudio audio) {
  return MaterialApp(
    home: PageViewerScreen(
      page: page,
      linesPerDay: linesPerDay,
      quran: fixtureQuran(),
      audio: audio,
    ),
  );
}

void main() {
  testWidgets('renders page, surah header and ayah rows', (tester) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.textContaining('Al-Faatiha'), findsWidgets);
    expect(find.text('أ'), findsOneWidget);
    expect(find.text('ب'), findsOneWidget);
  });

  testWidgets('highlights today portion (5 of 15 lines of 2 ayahs → 1)', (
    tester,
  ) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ayah-active-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-rest-1')), findsOneWidget);
    expect(find.textContaining('1 of 2'), findsOneWidget);
  });

  testWidgets('whole page highlighted when lines ≥ 15', (tester) async {
    await tester.pumpWidget(harness(2, 15, FakeQuranAudio()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ayah-active-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-active-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-rest-0')), findsNothing);
    expect(find.textContaining('whole page'), findsOneWidget);
  });

  testWidgets('play button plays today portion with default repeat', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Page 1 has 2 ayahs; 5 lines of 15 → highlight 1 → surah 1 ayah 1 only.
    expect(audio.playedUrls, [ayahAudioUrl(Reciter.alafasy, 1, 1)]);
    expect(audio.repeat, 3);
    expect(find.text("Playing today's portion"), findsOneWidget);
  });

  testWidgets('repeat selector changes the repeat count', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('repeat-selector')),
        matching: find.text('5'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(audio.repeat, 5);
  });

  testWidgets('pause toggles playback', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    expect(audio.paused, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('changing page stops playback', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(audio.stopped, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('page stepper moves between pages', (tester) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('ج'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
  });
}
