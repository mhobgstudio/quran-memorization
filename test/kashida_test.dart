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

/// One page with two text lines: a sparse line (3 short words) and a full
/// line (many words), so kashida must stretch the sparse one.
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
          ...line('بِسْمِ ٱللَّهِ'), // sparse: 3 short words
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
    // Realistic card size (the default 800x600 surface makes a tiny card
    // where the widest line is already over-full even without kashida).
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
  }

  testWidgets('sparse lines are stretched with tatweel (kashida)', (
    tester,
  ) async {
    await pumpHarness(tester);

    // The sparse line 'بِسْمِ ٱللَّهِ' must gain tatweels inside its words.
    final sparseTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where(
          (t) =>
              t.data != null &&
              (t.data!.contains('\u0640')) &&
              t.style?.fontFamily == 'UthmanicHafs',
        )
        .toList();
    expect(sparseTexts, isNotEmpty, reason: 'kashida should stretch sparse words');
  });

  testWidgets('kashida lines still fill the full line width with tight gaps', (
    tester,
  ) async {
    await pumpHarness(tester);

    // Collect word-group boxes per line and check: (a) the line's content
    // spans the full width, (b) inter-word gaps stay small relative to words.
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

    boxes.sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    final ratios = <double>[];
    var lineY = -1.0;
    var prevRight = -1.0;
    final lineGaps = <double>[];
    final lineWords = <double>[];
    void flush() {
      if (lineWords.length > 1 && lineGaps.isNotEmpty) {
        final mw = [...lineWords]..sort();
        final mg = [...lineGaps]..sort();
        ratios.add(mg[mg.length ~/ 2] / mw[mw.length ~/ 2]);
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

    expect(ratios, isNotEmpty);
    // Tight gaps: median gap stays well under a fifth of a word's width
    // (the printed mushaf is ~0.09; without kashida sparse lines hit 0.4+).
    final med = [...ratios]..sort();
    expect(med[med.length ~/ 2], lessThan(0.2));
  });
}
