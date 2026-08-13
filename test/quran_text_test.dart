import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled asset', () {
    late QuranText quran;

    setUpAll(() async {
      quran = await QuranText.load();
    });

    test('has 604 pages and 6236 ayahs across 114 surahs', () {
      expect(QuranText.totalPages, 604);
      var total = 0;
      for (var p = 1; p <= 604; p++) {
        final n = quran.ayahCountOnPage(p);
        expect(n, greaterThan(0), reason: 'page $p is empty');
        total += n;
      }
      expect(total, 6236);
    });

    test('page 1 is Al-Fatihah (7 ayahs) starting with basmala', () {
      final ayahs = quran.pageAyahs(1);
      expect(ayahs.length, 7);
      expect(ayahs.first.surah, 1);
      expect(ayahs.first.ayah, 1);
      expect(ayahs.first.text, isNotEmpty);
      expect(ayahs.last.reference, '1:7');
      expect(quran.surahInfo(1).transliteration, 'Al-Faatiha');
    });

    test('page 604 starts at 112:1 and ends at 114:6', () {
      final ayahs = quran.pageAyahs(604);
      expect(ayahs.first.reference, '112:1');
      expect(ayahs.last.reference, '114:6');
    });

    test('page 2 starts Al-Baqara at 2:1', () {
      final ayahs = quran.pageAyahs(2);
      expect(ayahs.first.surah, 2);
      expect(ayahs.first.ayah, 1);
      expect(quran.surahInfo(2).transliteration, 'Al-Baqara');
    });

    test('every ayah 1:1..114:6 is reachable exactly once', () {
      final seen = <String>{};
      for (var p = 1; p <= 604; p++) {
        for (final a in quran.pageAyahs(p)) {
          expect(
            seen.add(a.reference),
            isTrue,
            reason: 'duplicate ${a.reference}',
          );
        }
      }
      expect(seen.length, 6236);
    });

    test('page out of range throws', () {
      expect(() => quran.pageAyahs(0), throwsRangeError);
      expect(() => quran.pageAyahs(605), throwsRangeError);
    });
  });

  group('todayAyahCount', () {
    test('whole page for 15+ lines', () {
      expect(todayAyahCount(ayahsOnPage: 7, linesPerDay: 15), 7);
      expect(todayAyahCount(ayahsOnPage: 7, linesPerDay: 30), 7);
    });

    test('ceils the line fraction to ayah units', () {
      expect(todayAyahCount(ayahsOnPage: 7, linesPerDay: 5), 3);
      expect(todayAyahCount(ayahsOnPage: 15, linesPerDay: 1), 1);
    });

    test('zero or negative lines gives 0', () {
      expect(todayAyahCount(ayahsOnPage: 7, linesPerDay: 0), 0);
      expect(todayAyahCount(ayahsOnPage: 0, linesPerDay: 5), 0);
    });
  });
}
