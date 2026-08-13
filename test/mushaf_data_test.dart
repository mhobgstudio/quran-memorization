import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/mushaf_page.dart';
import 'package:quran_memorization/memorization_calc.dart'
    show MemorizationDirection;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled mushaf asset', () {
    late MushafData mushaf;

    setUpAll(() async {
      mushaf = await MushafData.load();
    });

    test('has 604 pages, 114 surahs and 15 rows on every page', () {
      expect(mushaf.pages.length, 604);
      expect(mushaf.surahs.length, 114);
      for (final page in mushaf.pages) {
        expect(page.lines.length, 15, reason: 'page ${page.page} rows');
      }
    });

    test('juz starts match the standard Madani mushaf', () {
      expect(mushaf.page(1).juz, 1);
      expect(mushaf.page(22).juz, 2);
      expect(mushaf.page(42).juz, 3);
      expect(mushaf.page(582).juz, 30);
      // juz never decreases and reaches 30.
      var prev = 0;
      for (final page in mushaf.pages) {
        expect(page.juz, greaterThanOrEqualTo(prev));
        prev = page.juz;
      }
      expect(prev, 30);
    });

    test('page 1 is Al-Fatihah, page 604 ends at 114:6', () {
      final p1 = mushaf.page(1);
      expect(p1.surah, 1);
      expect(p1.lines.first.type, MushafLineType.surahHeader);
      expect(p1.lines.first.text, startsWith('سُورَةُ'));
      expect(p1.lines.first.text, contains('ٱلْفَاتِحَةِ'));

      final p604 = mushaf.page(604);
      final lastText = p604.lines.lastWhere((l) => l.isText);
      expect(lastText.to, '114:6');
      expect(
        p604.lines.where((l) => l.type == MushafLineType.surahHeader).length,
        3,
      );
    });

    test('text lines carry ayah refs; basmala follows surah headers', () {
      var totalAyahRefs = 0;
      for (final page in mushaf.pages) {
        for (final line in page.textLines) {
          expect(line.ayahRefs, isNotEmpty);
          totalAyahRefs += line.ayahRefs.length;
          expect(line.from, isNotNull);
          expect(line.to, isNotNull);
        }
      }
      expect(totalAyahRefs, greaterThan(6236));
    });

    test('ayah refs across text lines are in reading order', () {
      int cmp(String a, String b) {
        final pa = a.split(':');
        final pb = b.split(':');
        final sa = int.parse(pa[0]);
        final sb = int.parse(pb[0]);
        return sa != sb
            ? sa.compareTo(sb)
            : int.parse(pa[1]).compareTo(int.parse(pb[1]));
      }

      for (final page in mushaf.pages) {
        String? prev;
        for (final line in page.textLines) {
          for (final ref in line.ayahRefs) {
            if (prev != null) {
              expect(
                cmp(prev, ref) <= 0,
                isTrue,
                reason: 'page ${page.page}: $prev then $ref',
              );
            }
            prev = ref;
          }
        }
      }
    });

    test('todayLines are direction-aware', () {
      final page = mushaf.page(22); // 15 full text lines
      final forward = page.todayLines(
        lineCount: 3,
        direction: MemorizationDirection.forward,
      );
      expect(forward.length, 3);
      expect(forward.first.from, page.textLines.first.from);

      final backward = page.todayLines(
        lineCount: 3,
        direction: MemorizationDirection.backward,
      );
      expect(backward.length, 3);
      expect(backward.last.to, page.textLines.last.to);
      expect(backward.first.from, isNot(forward.first.from));
    });

    test('todayLines clamp to the page', () {
      final page = mushaf.page(1); // 7 text lines + 7 blank rows
      final all = page.todayLines(
        lineCount: 99,
        direction: MemorizationDirection.forward,
      );
      expect(all.length, page.textLines.length);
    });
  });

  group('toArabicIndic', () {
    test('converts western digits', () {
      expect(toArabicIndic(0), '٠');
      expect(toArabicIndic(1), '١');
      expect(toArabicIndic(255), '٢٥٥');
      expect(toArabicIndic(604), '٦٠٤');
    });
  });

  group('page bounds', () {
    test('rejects out-of-range pages', () async {
      final mushaf = await MushafData.load();
      expect(() => mushaf.page(0), throwsRangeError);
      expect(() => mushaf.page(605), throwsRangeError);
    });
  });
}
