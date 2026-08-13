// Generates assets/quran_translation.json from alquran.cloud's Saheeh
// International edition (https://api.alquran.cloud/v1/quran/en.sahih).
//
// The output is a compact per-ayah array in the same global order as
// assets/quran_data.json (0 = 1:1, 6235 = 114:6), so translations and
// Uthmani text can be looked up with the same index.
//
// Usage: dart run tool/generate_quran_translation.dart [en.sahih.json] [out.json]
import 'dart:convert';
import 'dart:io';

const int totalAyahs = 6236;

void main(List<String> args) {
  final srcFile = args.isNotEmpty ? args[0] : '/tmp/en_sahih.json';
  final outFile = args.length > 1 ? args[1] : 'assets/quran_translation.json';

  final raw = jsonDecode(File(srcFile).readAsStringSync()) as Map<String, dynamic>;
  final edition = (raw['data'] as Map<String, dynamic>)['edition'] as Map<String, dynamic>;
  final surahs = (raw['data'] as Map<String, dynamic>)['surahs'] as List;

  final translations = <String>[];
  for (final s in surahs) {
    for (final a in (s as Map<String, dynamic>)['ayahs'] as List) {
      translations.add((a as Map<String, dynamic>)['text'] as String);
    }
  }
  if (translations.length != totalAyahs) {
    throw StateError('expected $totalAyahs ayahs, got ${translations.length}');
  }

  File(outFile).writeAsStringSync(jsonEncode({
    'meta': {
      'text': 'Quran English translation, Saheeh International, per ayah in '
          'global order (0 = 1:1). Source: alquran.cloud (api.alquran.cloud), '
          'edition ${edition['identifier']} — ${edition['englishName']}.',
      'edition': edition['identifier'],
      'ayahs': totalAyahs,
    },
    'translation': translations,
  }));
  stderr.writeln('wrote $outFile (${translations.length} ayahs, '
      '${(File(outFile).lengthSync() / 1024).toStringAsFixed(0)} KB)');
}
