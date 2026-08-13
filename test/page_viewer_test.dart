import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/mushaf_page.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/memorization_calc.dart'
    show MemorizationDirection;
import 'package:quran_memorization/screens/page_viewer_screen.dart';
import 'package:quran_memorization/services/audio_player.dart';
import 'package:quran_memorization/services/audio_settings.dart';
import 'package:quran_memorization/services/audio_unit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixture modeled on the real asset schema: page 1 = surah 1 with 14 text
/// lines (1:1..1:14), page 2 = surah 2 with basmala + 13 text lines
/// (2:1..2:13).
MushafData fixtureMushaf() {
  List<Map<String, dynamic>> textLines(int surah, int start, int count) => [
    for (var i = 0; i < count; i++)
      {
        't': 0,
        'x': 'كلمة$surah-${start + i} ${toArabicIndic(start + i)}',
        'f': '$surah:${start + i}',
        'g': '$surah:${start + i}',
        'a': ['$surah:${start + i}'],
      },
  ];

  return MushafData.fromJson({
    'surahs': [
      {
        's': 1,
        'n': 'الفاتحة',
        'l': 'سُورَةُ ٱلْفَاتِحَةِ',
        't': 'Al-Fatihah',
        'c': 7,
      },
      {'s': 2, 'n': 'البقرة', 'l': 'سورة البقرة', 't': 'Al-Baqarah', 'c': 13},
    ],
    'pages': [
      {
        'p': 1,
        'j': 1,
        's': 1,
        'l': [
          {'t': 1, 'x': 'سُورَةُ ٱلْفَاتِحَةِ'},
          ...textLines(1, 1, 14),
        ],
      },
      {
        'p': 2,
        'j': 1,
        's': 2,
        'l': [
          {'t': 1, 'x': 'سورة البقرة'},
          {'t': 2, 'x': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'},
          ...textLines(2, 1, 13),
        ],
      },
    ],
  });
}

class FakeQuranAudio implements QuranAudio {
  List<String>? playedUrls;
  int? repeat;
  bool paused = false;
  bool stopped = false;
  double? lastSpeed;
  final _completed = StreamController<void>.broadcast();

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
  Future<void> setSpeed(double speed) async => lastSpeed = speed;

  @override
  Future<void> dispose() async {}

  @override
  Stream<void> get onCompleted => _completed.stream;

  /// Emits a completion event, as if the current unit finished.
  void finish() => _completed.add(null);
}

Widget harness(
  int page,
  double linesPerDay,
  FakeQuranAudio audio, {
  MemorizationDirection direction = MemorizationDirection.forward,
  AudioUnitController? unit,
  int reviewDays = 0,
}) {
  return MaterialApp(
    home: PageViewerScreen(
      page: page,
      linesPerDay: linesPerDay,
      direction: direction,
      mushaf: fixtureMushaf(),
      audio: audio,
      unit: unit,
      reviewDays: reviewDays,
    ),
  );
}

void main() {
  testWidgets('renders mushaf page with header band, lines and ornaments', (
    tester,
  ) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-rest-6')), findsOneWidget);
    // Inline WidgetSpan children are not traversed by find.byKey;
    // ornament keys are visible to the widget predicate.
    expect(
      find.byWidgetPredicate((w) => w.key.toString().contains('ayah-ornament')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('surah-banner-0')), findsNothing);
  });

  testWidgets('header shows Arabic-Indic page, juz and surah name', (
    tester,
  ) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    final number = tester.widget<Text>(
      find.byKey(const ValueKey('page-header-number')),
    );
    expect(number.data, '١');
    final juz = tester.widget<Text>(
      find.byKey(const ValueKey('page-header-juz')),
    );
    expect(juz.data, 'الجزء ١');
    final surah = tester.widget<Text>(
      find.byKey(const ValueKey('page-header-surah')),
    );
    expect(surah.data, 'سُورَةُ ٱلْفَاتِحَةِ');
  });

  testWidgets('highlights the first lines when memorizing forward', (
    tester,
  ) async {
    await tester.pumpWidget(harness(1, 5, FakeQuranAudio()));
    await tester.pumpAndSettle();

    // Page 1: rows 1..14 are text; 5 lines → row indices 1..5.
    expect(find.byKey(const ValueKey('line-active-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-6')), findsNothing);
    expect(find.byKey(const ValueKey('line-rest-6')), findsOneWidget);
    expect(find.textContaining('first 5 of 14'), findsOneWidget);
  });

  testWidgets('highlights the last lines when memorizing backward', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        2,
        3,
        FakeQuranAudio(),
        direction: MemorizationDirection.backward,
      ),
    );
    await tester.pumpAndSettle();

    // Page 2: rows 2..14 are text (13 lines); last 3 → row indices 12..14.
    expect(find.byKey(const ValueKey('line-active-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-2')), findsNothing);
    expect(find.textContaining('last 3 of 13'), findsOneWidget);
  });

  testWidgets('whole page highlighted when lines ≥ page lines', (tester) async {
    await tester.pumpWidget(harness(1, 15, FakeQuranAudio()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('line-active-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-rest-14')), findsNothing);
    expect(find.textContaining('the whole page'), findsOneWidget);
  });

  testWidgets('play button plays today ayahs with default repeat', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(audio.playedUrls, [
      for (var a = 1; a <= 5; a++) ayahAudioUrl(Reciter.alafasy, 1, a),
    ]);
    expect(audio.repeat, 3);
    expect(find.text("Playing today's portion"), findsOneWidget);
  });

  testWidgets('backward play uses the last lines ayahs', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(
      harness(2, 3, audio, direction: MemorizationDirection.backward),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(audio.playedUrls, [
      for (var a = 11; a <= 13; a++) ayahAudioUrl(Reciter.alafasy, 2, a),
    ]);
  });

  testWidgets('speed selector sets the playback speed', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('speed-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×').last);
    await tester.pumpAndSettle();

    expect(audio.lastSpeed, 1.5);
    expect(find.textContaining('1.5×'), findsWidgets);
  });

  testWidgets('reciter picker changes the recitation URLs', (tester) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reciter-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Husary (murattal)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(audio.playedUrls, [
      for (var a = 1; a <= 5; a++) ayahAudioUrl(Reciter.husary, 1, a),
    ]);
    expect(find.textContaining('Husary (murattal)'), findsWidgets);
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

  testWidgets('infinite loop option plays until stopped (repeat 0)', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('repeat-selector')),
        matching: find.text('∞'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(audio.repeat, 0);
    expect(find.textContaining('until stopped'), findsOneWidget);
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
    final surah = tester.widget<Text>(
      find.byKey(const ValueKey('page-header-surah')),
    );
    expect(surah.data, 'سورة البقرة');

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('echo mode plays one ayah at a time and auto-pauses', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(1, 5, audio));

    // Turn echo on and play: only the first ayah is queued (5 lines today).
    await tester.tap(find.byKey(const ValueKey('echo-toggle')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(audio.playedUrls!.length, 1);
    expect(find.textContaining('Echo — ayah 1 of 5'), findsOneWidget);

    // Auto-pause after the ayah completes and advance to the next.
    audio.finish();
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.textContaining('Echo — ayah 2 of 5'), findsOneWidget);

    // The next play queues only the next ayah again.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(audio.playedUrls!.length, 1);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('audio dedupes boundary ayahs shared by adjacent lines', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    final mushaf = MushafData.fromJson({
      'surahs': [
        {
          's': 1,
          'n': 'الفاتحة',
          'l': 'سُورَةُ ٱلْفَاتِحَةِ',
          't': 'Al-Fatihah',
          'c': 7,
        },
        {'s': 2, 'n': 'البقرة', 'l': 'سورة البقرة', 't': 'Al-Baqarah', 'c': 4},
      ],
      'pages': [
        {
          'p': 1,
          'j': 1,
          's': 2,
          'l': [
            {'t': 1, 'x': 'سورة البقرة'},
            {
              't': 0,
              'x': 'أ ١ ب ٢',
              'f': '2:1',
              'g': '2:2',
              'a': ['2:1', '2:2'],
            },
            {
              't': 0,
              'x': 'ج ٣',
              'f': '2:2',
              'g': '2:3',
              'a': ['2:2', '2:3'],
            },
            for (var i = 0; i < 12; i++) {'t': 3, 'x': ''},
          ],
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PageViewerScreen(
          page: 1,
          linesPerDay: 2,
          mushaf: mushaf,
          audio: audio,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // 2:2 is shared by both lines; it must play exactly once.
    expect(audio.playedUrls, [
      ayahAudioUrl(Reciter.alafasy, 2, 1),
      ayahAudioUrl(Reciter.alafasy, 2, 2),
      ayahAudioUrl(Reciter.alafasy, 2, 3),
    ]);
  });

  testWidgets('audio disabled when no lines assigned', (tester) async {
    await tester.pumpWidget(harness(1, 0, FakeQuranAudio()));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.play_arrow),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('first 0 of 14'), findsOneWidget);
  });
  testWidgets('changing the repeat selector persists the new default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final unit = AudioUnitController(audio: FakeQuranAudio());

    await tester.pumpWidget(harness(1, 5, FakeQuranAudio(), unit: unit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    final loaded = await AudioSettings.load();
    expect(loaded.repeat, 5);
    expect(unit.repeat, 5);
    unit.dispose();
  });
  group('reviewSegments', () {
    test('forward walks back to earlier pages, oldest first', () {
      final m = fixtureMushaf();
      final segs = m.reviewSegments(
        currentPage: 2,
        linesPerDay: 5,
        direction: MemorizationDirection.forward,
        reviewDays: 3,
      );
      expect(segs, const [
        ReviewSegment(page: 1, startLine: 4, lineCount: 10),
        ReviewSegment(page: 2, startLine: 0, lineCount: 5),
      ]);
    });

    test('backward walks to later pages, oldest first', () {
      final m = fixtureMushaf();
      final segs = m.reviewSegments(
        currentPage: 1,
        linesPerDay: 5,
        direction: MemorizationDirection.backward,
        reviewDays: 3,
      );
      expect(segs, const [
        ReviewSegment(page: 2, startLine: 0, lineCount: 10),
        ReviewSegment(page: 1, startLine: 9, lineCount: 5),
      ]);
    });

    test('clamps when the mushaf runs out (page 1 forward)', () {
      final m = fixtureMushaf();
      final segs = m.reviewSegments(
        currentPage: 1,
        linesPerDay: 5,
        direction: MemorizationDirection.forward,
        reviewDays: 3,
      );
      expect(segs, const [ReviewSegment(page: 1, startLine: 0, lineCount: 5)]);
    });

    test('empty when reviewDays is 0', () {
      final m = fixtureMushaf();
      expect(
        m.reviewSegments(
          currentPage: 2,
          linesPerDay: 5,
          direction: MemorizationDirection.forward,
          reviewDays: 0,
        ),
        isEmpty,
      );
    });
  });

  testWidgets('review mode opens at the window start and highlights it', (
    tester,
  ) async {
    await tester.pumpWidget(harness(2, 5, FakeQuranAudio(), reviewDays: 3));
    await tester.pumpAndSettle();

    // Opens on page 1 (oldest page of the window), not today's page 2.
    expect(find.text('Page 1'), findsOneWidget);
    expect(
      find.textContaining('Review (last 3 days): first 10 of 14 lines'),
      findsOneWidget,
    );
    // Window on page 1: text lines 4..13 -> rows 5..14 highlighted.
    expect(find.byKey(const ValueKey('line-active-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-active-1')), findsNothing);
  });

  testWidgets('review mode queues the last 3 days of lines oldest-first', (
    tester,
  ) async {
    final audio = FakeQuranAudio();
    await tester.pumpWidget(harness(2, 5, audio, reviewDays: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play the review queue'));
    await tester.pump();

    // 10 lines of page 1 (1:5..1:14) then 5 lines of page 2 (2:1..2:5).
    expect(audio.playedUrls, hasLength(15));
    expect(audio.playedUrls!.first, ayahAudioUrl(Reciter.alafasy, 1, 5));
    expect(audio.playedUrls![9], ayahAudioUrl(Reciter.alafasy, 1, 14));
    expect(audio.playedUrls![10], ayahAudioUrl(Reciter.alafasy, 2, 1));
    expect(audio.playedUrls!.last, ayahAudioUrl(Reciter.alafasy, 2, 5));
  });
}
