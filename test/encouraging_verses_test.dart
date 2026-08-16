import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/encouraging_verses.dart';

void main() {
  group('kEncouragingVerses', () {
    test(
      'is non-empty and every entry has reference, arabic and translation',
      () {
        expect(kEncouragingVerses, isNotEmpty);
        for (final v in kEncouragingVerses) {
          expect(
            RegExp(r'^\d+:\d+$').hasMatch(v.reference),
            isTrue,
            reason: 'reference should be "surah:ayah", got ${v.reference}',
          );
          expect(v.arabic.trim(), isNotEmpty);
          expect(v.translation.trim(), isNotEmpty);
        }
      },
    );
  });

  group('encouragingVerseFor', () {
    test('is deterministic for the same date', () {
      final a = encouragingVerseFor(DateTime(2026, 8, 16));
      final b = encouragingVerseFor(DateTime(2026, 8, 16));
      expect(a, same(b));
    });

    test('rotates daily, covering every verse before repeating', () {
      final seen = <String>{};
      final start = DateTime(2026, 8, 16);
      for (var d = 0; d < kEncouragingVerses.length; d++) {
        final v = encouragingVerseFor(start.add(Duration(days: d)));
        seen.add(v.reference);
      }
      expect(
        seen.length,
        kEncouragingVerses.length,
        reason: 'every verse should appear within one full cycle',
      );
    });

    test('handles dates before the epoch anchor (negative offsets)', () {
      final v = encouragingVerseFor(DateTime(2020, 1, 1));
      expect(kEncouragingVerses, contains(v));
    });
  });
}
