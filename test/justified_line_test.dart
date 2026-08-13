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

  testWidgets('justified lines still span the full width with word gaps', (
    tester,
  ) async {
    await pumpHarness(tester);

    // Collect word-group boxes per line: the justified text lines must reach
    // the card's right edge (full-width via spaceBetween word gaps).
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

    final maxRight = boxes.map((b) => b.x + b.w).reduce((a, b) => a > b ? a : b);

    boxes.sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    var lineY = -1.0;
    var prevRight = -1.0;
    final lineGaps = <double>[];
    final lineWords = <double>[];
    final lineEdges = <double>[];
    final allGaps = <double>[];
    void flush() {
      if (lineWords.isNotEmpty) {
        lineEdges.add(prevRight);
        if (lineGaps.isNotEmpty) {
          allGaps.addAll(lineGaps);
          lineGaps.sort();
        }
      }
      lineGaps.clear();
      lineWords.clear();
    }
    for (final b in boxes) {
      if (lineY < 0 || (b.y - lineY).abs() > 8) {
        flush();
        lineY = b.y;
        prevRight = b.x + b.w;
        lineWords.add(b.w);
      } else {
        lineGaps.add(b.x - prevRight);
        prevRight = b.x + b.w;
        lineWords.add(b.w);
      }
    }
    flush();

    // Both justified text lines (the sparse 3-word line and the dense line)
    // must reach the card's right edge. The surah banner and basmala are
    // centred by design and don't reach it.
    final justifiedEdges = lineEdges
        .where((e) => (e - maxRight).abs() < 2.0)
        .length;
    expect(justifiedEdges, greaterThanOrEqualTo(2),
        reason: 'justified lines must span the full width');
    // Sparse lines carry wide inter-word gaps (the natural word-gap spacing
    // that replaced kashida).
    expect(allGaps, isNotEmpty);
  });
}
