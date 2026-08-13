/// Reciters available for per-ayah audio (EveryAyah CDN).
///
/// Folder names and bitrates verified against
/// https://everyayah.com/data/ (public, free for non-commercial apps).
enum Reciter {
  alafasy('Alafasy', 'Alafasy_128kbps'),
  husary('Husary (murattal)', 'Husary_128kbps'),
  husaryMujawwad('Husary (mujawwad)', 'Husary_128kbps_Mujawwad'),
  minshawi('Minshawi (murattal)', 'Minshawy_Murattal_128kbps'),
  sudais('Sudais', 'Abdurrahmaan_As-Sudais_192kbps');

  const Reciter(this.label, this.folder);

  /// Display name.
  final String label;

  /// Folder name on the EveryAyah CDN.
  final String folder;
}

/// Base of the EveryAyah CDN.
const String everyAyahBaseUrl = 'https://everyayah.com/data/';

/// Per-ayah MP3 URL for [reciter], e.g. surah 2 ayah 255 →
/// https://everyayah.com/data/Alafasy_128kbps/002255.mp3
String ayahAudioUrl(Reciter reciter, int surah, int ayah) {
  final sss = surah.toString().padLeft(3, '0');
  final nnn = ayah.toString().padLeft(3, '0');
  return '$everyAyahBaseUrl${reciter.folder}/$sss$nnn.mp3';
}
