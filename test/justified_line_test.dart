import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/mushaf_page.dart';
import 'package:quran_memorization/memorization_calc.dart';
import 'package:quran_memorization/screens/page_viewer_screen.dart';
import 'package:quran_memorization/services/audio_player.dart';

class _FakeAudio implements QuranAudio {
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
  Stream<void> get onCompleted => const Stream.empty();
}

/// One page with two justified text lines — a sparse line (3 short words) and
/// a dense line (many words) — plus the usual header band and basmala, so the
/// sparse line must fill the full width via its word gaps (no kashida).
MushafData _fixture() {
  List<Map<String, dynamic>> line(String text) => [
        {'t': 0, 'x': text, 'f': '1:1', 'g': '1:1', 'a': ['1:1']},
      ];
  return MushafData.fromJson({
    'surahs': [
      {'s': 1, 'n': 'الفاتحة', 'l': 'سُورَةُ ٱلْفَاتِحَةِ', 't': 'Al-Fatihah', 'c': 2},
    ],
    'pages': [
      {
        'p': 1,
        'j': 1,
        's': 1,
        'l': [
          {'t': 1, 'x': 'سُورَةُ ٱلْفَاتِحَةِ'},
          ...line('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'),
          ...line('قُلْ هُوَ ٱللَّهُ'), // sparse: 3 short words
          ...line(
            'وَٱلضُّحَىٰ وَٱلَّيْلِ إِذَا سَجَىٰ مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ',
          ),
        ],
      },
    ],
  });
}

Widget _harness() {
  return MaterialApp(
    home: PageViewerScreen(
      page: 1,
      linesPerDay: 3,
      direction: MemorizationDirection.forward,
      mushaf: _fixture(),
      audio: _FakeAudio(),
    ),
  );
}

void main() {
  Future<void> pumpHarness(WidgetTester tester) async {
    final fontData = File('assets/fonts/UthmanicHafs1.otf').readAsBytesSync();
    final loader = FontLoader('UthmanicHafs');
    loader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await loader.load();
    // Realistic card size so the widest line fits at the natural font size.
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
  }

  testWidgets('rendered words match the source exactly (no inserted tatweel)', (
    tester,
  ) async {
    await pumpHarness(tester);

    // Regression: kashida letter-stretching was removed — every rendered word
    // must be exactly one of the mushaf's own words (the Uthmani script has
    // natural tatweels, e.g. in الرحمن, but nothing may be added). The header
    // band also renders the juz label ("الجزء ١"), which is legitimate.
    final fixture = _fixture();
    final source = <String>{};
    for (final line in fixture.pages.first.lines) {
      source.addAll(line.text.split(' ').where((w) => w.isNotEmpty));
    }
    for (final surah in fixture.surahs) {
      source.addAll(surah.arabicLong.split(' ').where((w) => w.isNotEmpty));
    }
    source
      ..add('الجزء')
      // The header band renders its juz and surah-name labels as single
      // strings (with the space inside), e.g. "الجزء ١" and the surah name.
      ..add('الجزء ١')
      ..addAll(
        fixture.surahs.map((s) => s.arabicLong).where((s) => s.isNotEmpty),
      );
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data != null && t.style?.fontFamily == 'UthmanicHafs')
        .map((t) => t.data!)
        .toList();
    expect(rendered, isNotEmpty);
    // Skip the ayah-rosette digits (e.g. "١") — those are the ornament
    // numbers, not stretched text.
    final digitOnly = RegExp(r'^[٠-٩]+$');
    for (final word in rendered) {
      if (digitOnly.hasMatch(word)) continue;
      expect(
        source.contains(word),
        isTrue,
        reason: 'rendered word "$word" is not in the mushaf source — '
            'kashida must not alter the text',
      );
    }
  });

  testWidgets('text lines are centred in the page at natural width', (
    tester,
  ) async {
    await pumpHarness(tester);

    // Collect word-group boxes per line: every multi-word line's content
    // must sit centred in the page card (its own natural width, with the
    // leftover shared equally on both sides) rather than justified edge to
    // edge.
    final groupRows = find.byWidgetPredicate((w) {
      if (w is! Row || w.mainAxisSize != MainAxisSize.min) return false;
      return tester
          .widgetList<Text>(
            find.descendant(of: find.byWidget(w), matching: find.byType(Text)),
          )
          .any((t) => t.style?.fontFamily == 'UthmanicHafs');
    });
    final boxes = <({double y, double x, double w})>[];
    for (final w in tester.widgetList<Row>(groupRows)) {
      final box = tester.renderObject<RenderBox>(find.byWidget(w));
      final pos = box.localToGlobal(Offset.zero);
      boxes.add((y: pos.dy, x: pos.dx, w: box.size.width));
    }
    expect(boxes.length, greaterThan(5));

    // The page card spans from the leftmost to the rightmost rendered box
    // (its frame contains all content).
    final minLeft = boxes.map((b) => b.x).reduce((a, b) => a < b ? a : b);
    final maxRight = boxes.map((b) => b.x + b.w).reduce((a, b) => a > b ? a : b);
    final cardCenter = (minLeft + maxRight) / 2;

    boxes.sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    var lineY = -1.0;
    var firstLeft = -1.0;
    var lastRight = -1.0;
    final lineCenters = <double>[];
    void flush() {
      if (firstLeft >= 0) lineCenters.add((firstLeft + lastRight) / 2);
      firstLeft = -1;
      lastRight = -1;
    }
    for (final b in boxes) {
      if (lineY < 0 || (b.y - lineY).abs() > 8) {
        flush();
        lineY = b.y;
        firstLeft = b.x;
        lastRight = b.x + b.w;
      } else {
        lastRight = b.x + b.w;
      }
    }
    flush();

    // Every text line (sparse and dense alike) is centred: its middle sits
    // at the card's centre. Centring is the explicit intent here, so the
    // dense line's near-full width still counts — only its middle must match.
    expect(lineCenters.length, greaterThanOrEqualTo(2));
    for (final center in lineCenters) {
      expect(center, closeTo(cardCenter, 3.0),
          reason: 'line must be centred in the page');
    }
  });
}
