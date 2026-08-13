// Generates assets/quran_data.json from two offline sources:
//   1) Uthmani text  : fawazahmed0/quran-api edition ara-quranuthmanihaf
//      (https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranuthmanihaf.json)
//   2) Page layout   : Tanzil Project metadata, cc-by
//      (https://tanzil.net/res/text/metadata/quran-data.xml) — each <page>
//      gives the (sura, aya) where the Madani mushaf page starts.
//
// Usage: dart run tool/generate_quran_data.dart [text.json] [tanzil-meta.xml] [out.json]
import 'dart:convert';
import 'dart:io';

const int totalAyahs = 6236;
const int totalPages = 604;

void main(List<String> args) {
  final textFile = args.isNotEmpty ? args[0] : '/tmp/quran-text.json';
  final metaFile = args.length > 1 ? args[1] : '/tmp/tanzil-meta.xml';
  final outFile = args.length > 2 ? args[2] : 'assets/quran_data.json';

  // 1) Uthmani text.
  final raw =
      jsonDecode(File(textFile).readAsStringSync()) as Map<String, dynamic>;
  final entries = (raw['quran'] as List).cast<Map<String, dynamic>>();
  final texts = [for (final e in entries) (e['text'] as String).trim()];
  if (texts.length != totalAyahs) {
    throw StateError('expected $totalAyahs ayahs, got ${texts.length}');
  }

  // 2) Tanzil metadata: surah offsets + names, and page start ayahs.
  final xml = File(metaFile).readAsStringSync();
  final suraRe = RegExp(
    r'<sura index="(\d+)" ayas="(\d+)" start="(\d+)"[^>]*?name="([^"]*)"[^>]*?tname="([^"]*)"',
  );
  final surahs = <Map<String, Object>>[];
  final suraStart = <int, int>{};
  for (final m in suraRe.allMatches(xml)) {
    final s = int.parse(m.group(1)!);
    suraStart[s] = int.parse(m.group(3)!);
    surahs.add({
      's': s,
      'c': int.parse(m.group(2)!),
      'n': m.group(4)!,
      't': m.group(5)!,
    });
  }
  if (surahs.length != 114) {
    throw StateError('expected 114 surahs, got ${surahs.length}');
  }

  final pageRe = RegExp(r'<page index="(\d+)" sura="(\d+)" aya="(\d+)"');
  final pageStart = <int, int>{};
  for (final m in pageRe.allMatches(xml)) {
    final sura = int.parse(m.group(2)!);
    final aya = int.parse(m.group(3)!);
    pageStart[int.parse(m.group(1)!)] = suraStart[sura]! + aya - 1;
  }
  if (pageStart.length != totalPages) {
    throw StateError('expected $totalPages pages, got ${pageStart.length}');
  }

  // 3) Pages as global ayah indices.
  final pages = <List<int>>[];
  for (var p = 1; p <= totalPages; p++) {
    final start = pageStart[p]!;
    final end = p == totalPages ? totalAyahs : pageStart[p + 1]!;
    pages.add([for (var i = start; i < end; i++) i]);
  }

  // 4) Validate: every ayah appears exactly once, no empty page.
  final seen = <int>{};
  for (final pg in pages) {
    if (pg.isEmpty) throw StateError('empty page');
    for (final i in pg) {
      if (!seen.add(i)) throw StateError('duplicate ayah index $i');
    }
  }
  if (seen.length != totalAyahs) {
    throw StateError('expected $totalAyahs unique ayahs, got ${seen.length}');
  }

  // 5) Sanity: page 1 starts at 1:1, page 604 ends at 114:6.
  if (pageStart[1] != 0) throw StateError('page 1 does not start at 1:1');
  if (pages[603].last != totalAyahs - 1) {
    throw StateError('page 604 does not end at 114:6');
  }

  final out = <String, Object>{
    'meta': {
      'text':
          'Quran Uthmani text (fawazahmed0/quran-api, ara-quranuthmanihaf) and Madani page layout (Tanzil Project metadata, cc-by)',
      'ayahs': totalAyahs,
      'pages': totalPages,
      'linesPerPage': 15,
    },
    'surahs': surahs,
    'text': texts,
    'pages': pages,
  };
  File(outFile).parent.createSync(recursive: true);
  File(outFile).writeAsStringSync(const JsonEncoder().convert(out));
  stdout.writeln(
    'Wrote $outFile (${File(outFile).lengthSync()} bytes), '
    '${pages.length} pages, ${texts.length} ayahs',
  );
}
