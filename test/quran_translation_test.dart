import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_text.dart';
import 'package:quran_memorization/data/quran_translation.dart';

QuranText fixtureQuranText() {
  return QuranText.fromJson({
    'text': [for (var k = 1; k <= 7; k++) 'نص 1:$k', for (var k = 1; k <= 3; k++) 'نص 2:$k'],
    'pages': [
      [for (var i = 0; i < 7; i++) i],
      [for (var i = 7; i < 10; i++) i],
    ],
    'surahs': [
      {'s': 1, 'c': 7, 'n': 'الفاتحة', 't': 'Al-Fatihah'},
      {'s': 2, 'c': 3, 'n': 'البقرة', 't': 'Al-Baqarah'},
    ],
  });
}

QuranTranslation fixtureTranslation() {
  final t = List<String>.filled(QuranTranslation.totalAyahs, 'placeholder');
  t[0] = 'Meaning of 1:1';
  t[6] = 'Meaning of 1:7';
  t[7] = 'Meaning of 2:1';
  return QuranTranslation.fromJson({
    'meta': {'edition': 'en.sahih'},
    'translation': t,
  });
}

void main() {
  test('translationAt reads the bundled global order', () {
    final t = fixtureTranslation();
    expect(t.edition, 'en.sahih');
    expect(t.translationAt(0), 'Meaning of 1:1');
    expect(t.translationAt(6), 'Meaning of 1:7');
    expect(t.translationAt(7), 'Meaning of 2:1');
    expect(() => t.translationAt(-1), throwsRangeError);
    expect(() => t.translationAt(QuranTranslation.totalAyahs), throwsRangeError);
  });

  test('fromJson rejects a wrong-sized translation list', () {
    expect(
      () => QuranTranslation.fromJson({
        'meta': const {'edition': 'en.sahih'},
        'translation': ['only one'],
      }),
      throwsStateError,
    );
  });

  test('globalIndex and ayahAtRef agree with translationAt', () {
    final q = fixtureQuranText();
    expect(q.globalIndex(1, 1), 0);
    expect(q.globalIndex(1, 7), 6);
    expect(q.globalIndex(2, 1), 7);
    expect(q.ayahAtRef(2, 1).text, 'نص 2:1');
    expect(() => q.globalIndex(1, 8), throwsRangeError);
    expect(() => q.globalIndex(3, 1), throwsRangeError);
  });
}
