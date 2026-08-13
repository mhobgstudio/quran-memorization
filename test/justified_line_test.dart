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

  testWidgets('text lines are centred AND evenly spaced across the page', (
    tester,
  ) async {
    await pumpHarness(tester);

    // The justified lines are the outer max-size Rows holding the word
    // groups; their own bounds define the line's full width (the card frame
    // has padding, so we must not measure against it).
    final outerRows = find.byWidgetPredicate((w) {
      if (w is! Row || w.mainAxisSize != MainAxisSize.max) return false;
      return tester
          .widgetList<Text>(
            find.descendant(of: find.byWidget(w), matching: find.byType(Text)),
          )
          .any((t) => t.style?.fontFamily == 'UthmanicHafs');
    });
    final outerBoxes = <({double y, double left, double right})>[];
    for (final w in tester.widgetList<Row>(outerRows)) {
      final box = tester.renderObject<RenderBox>(find.byWidget(w));
      final pos = box.localToGlobal(Offset.zero);
      outerBoxes.add(
        (y: pos.dy, left: pos.dx, right: pos.dx + box.size.width),
      );
    }
    expect(outerBoxes.length, greaterThanOrEqualTo(2),
        reason: 'expected the sparse and dense justified lines');
    final cardCenter = (outerBoxes.first.left + outerBoxes.first.right) / 2;

    // Collect each line's word-group boxes: for every justified max-Row,
    // find its own direct child min-Rows (scoped per widget instance).
    final outerWidgets = tester.widgetList<Row>(outerRows).toList();
    final lines = <List<({double x, double w})>>[];
    for (var i = 0; i < outerWidgets.length; i++) {
      final outerWidget = outerWidgets[i];
      final groupRows = find.descendant(
        of: find.byWidget(outerWidget),
        matching: find.byWidgetPredicate(
          (w) => w is Row && w.mainAxisSize == MainAxisSize.min,
        ),
      );
      final line = <({double x, double w})>[];
      for (final g in tester.widgetList<Row>(groupRows)) {
        final box = tester.renderObject<RenderBox>(find.byWidget(g));
        final pos = box.localToGlobal(Offset.zero);
        line.add((x: pos.dx, w: box.size.width));
      }
      line.sort((a, b) => a.x.compareTo(b.x));
      if (line.length >= 3) {
        lines.add(line);
      } else {
        // Keep the pairing intact: record an empty slot for short lines so
        // lines[i] still corresponds to outerBoxes[i].
        lines.add(const []);
      }
    }
    final spaced = lines.where((l) => l.length >= 3).toList();
    expect(spaced.length, greaterThanOrEqualTo(1),
        reason: 'need at least one multi-word line to assert spacing');

    for (var i = 0; i < outerBoxes.length; i++) {
      final line = lines[i];
      if (line.length < 3) continue;
      final outer = outerBoxes[i];
      final first = line.first;
      final last = line.last;

      // (a) Centred: the line's middle sits at the page centre.
      final lineCenter = (first.x + (last.x + last.w)) / 2;
      expect(lineCenter, closeTo(cardCenter, 3.0),
          reason: 'line must be centred in the page');

      // (b) Justified: spaceEvenly divides the leftover into equal gaps —
      // before the first word, between words, and after the last word.
      final gaps = <double>[];
      gaps.add(first.x - outer.left); // left edge gap
      for (var k = 1; k < line.length; k++) {
        gaps.add(line[k].x - (line[k - 1].x + line[k - 1].w));
      }
      gaps.add(outer.right - (last.x + last.w)); // right edge gap
      final firstGap = gaps.first;
      for (final g in gaps) {
        expect(g, closeTo(firstGap, 3.0),
            reason: 'spacing must be evenly distributed (centred + justified)');
      }
      // And the spacing is non-trivial: the line is actually spread out.
      expect(firstGap, greaterThan(2.0));
    }
  });
}
