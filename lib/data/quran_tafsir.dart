import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A single tafsir (commentary) entry for one or more ayahs.
@immutable
class TafsirEntry {
  const TafsirEntry({
    required this.surah,
    required this.ayah,
    required this.title,
    required this.commentary,
    this.source = "Ibn Kathir",
  });

  /// Surah number (1..114).
  final int surah;

  /// Ayah number within the surah (1..286).
  final int ayah;

  /// Short descriptive title, e.g. "Ayat al-Kursi — The Throne Verse".
  final String title;

  /// The tafsir commentary text (plain text, may be multi-paragraph).
  final String commentary;

  /// Scholar/source attribution.
  final String source;

  /// Compact key for lookups: "surah:ayah", e.g. "2:255".
  String get ref => '$surah:$ayah';
}

/// Bundled curated tafsir data (offline-first).
///
/// Loaded from assets/quran_tafsir.json. Contains commentary for ~250
/// of the most important and commonly-referenced ayahs, drawn primarily
/// from Ibn Kathir's tafsir with supplementary notes from other classical
/// scholars where noted.
@immutable
class TafsirData {
  TafsirData._({required this._entries});

  final List<TafsirEntry> _entries;

  /// Lookup map: "surah:ayah" → entry, built on load.
  final Map<String, TafsirEntry> _index = {};

  /// Parses the bundled JSON.
  factory TafsirData.fromJson(Map<String, dynamic> json) {
    final list = (json['tafsir'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return TafsirEntry(
        surah: m['surah'] as int,
        ayah: m['ayah'] as int,
        title: m['title'] as String,
        commentary: m['commentary'] as String,
        source: m['source'] as String? ?? 'Ibn Kathir',
      );
    }).toList();
    return TafsirData._(entries: list);
  }

  /// Loads the bundled asset.
  static Future<TafsirData> load() async {
    final raw = await rootBundle.loadString('assets/quran_tafsir.json');
    final data = TafsirData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    data._buildIndex();
    return data;
  }

  /// Builds the lookup index after construction.
  void _buildIndex() {
    _index.clear();
    for (final e in _entries) {
      _index[e.ref] = e;
    }
  }

  /// Total number of tafsir entries.
  int get length => _entries.length;

  /// Returns the tafsir for surah [surah] ayah [ayah], or null if not
  /// available in this curated collection.
  TafsirEntry? tafsirAt(int surah, int ayah) {
    return _index['$surah:$ayah'];
  }

  /// Returns the tafsir for a "surah:ayah" reference string.
  TafsirEntry? tafsirAtRef(String ref) => _index[ref];

  /// All available tafsir entries, in order.
  List<TafsirEntry> get allEntries => List.unmodifiable(_entries);

  /// Ayahs on a given page that have tafsir available, as (surah, ayah) pairs.
  List<(int, int)> ayahsWithTafsirOnPage(List<String> ayahRefs) {
    final result = <(int, int)>[];
    for (final ref in ayahRefs) {
      if (_index.containsKey(ref)) {
        final parts = ref.split(':');
        result.add((int.parse(parts[0]), int.parse(parts[1])));
      }
    }
    return result;
  }
}
