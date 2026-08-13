import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';

void main() {
  group('ayahAudioUrl', () {
    test('Alafasy surah 1 ayah 1', () {
      expect(
        ayahAudioUrl(Reciter.alafasy, 1, 1),
        'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
      );
    });

    test('Sudais surah 2 ayah 255 (Ayah al-Kursi)', () {
      expect(
        ayahAudioUrl(Reciter.sudais, 2, 255),
        'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/002255.mp3',
      );
    });

    test('Husary mujawwad last ayah 114:6', () {
      expect(
        ayahAudioUrl(Reciter.husaryMujawwad, 114, 6),
        'https://everyayah.com/data/Husary_128kbps_Mujawwad/114006.mp3',
      );
    });

    test('every reciter builds a well-formed URL', () {
      for (final r in Reciter.values) {
        final url = ayahAudioUrl(r, 2, 255);
        expect(url, startsWith('https://everyayah.com/data/'));
        expect(url, endsWith('/002255.mp3'));
      }
    });
  });
}
