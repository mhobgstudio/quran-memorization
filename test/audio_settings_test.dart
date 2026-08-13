import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/services/audio_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults when nothing is stored', () async {
    final s = await AudioSettings.load();
    expect(s.reciter, Reciter.alafasy);
    expect(s.speed, 1.0);
    expect(s.repeat, 3);
  });

  test('save then load round-trips all three settings', () async {
    await const AudioSettings(
      reciter: Reciter.husary,
      speed: 1.5,
      repeat: 0,
    ).save();

    final s = await AudioSettings.load();
    expect(s.reciter, Reciter.husary);
    expect(s.speed, 1.5);
    expect(s.repeat, 0);
  });

  test('an unknown stored reciter name falls back to alafasy', () async {
    SharedPreferences.setMockInitialValues({
      'audio.reciter': 'not-a-reciter',
      'audio.speed': 0.5,
    });

    final s = await AudioSettings.load();
    expect(s.reciter, Reciter.alafasy);
    expect(s.speed, 0.5);
    expect(s.repeat, 3);
  });

  test('copyWith keeps the unchanged fields', () {
    const base = AudioSettings(reciter: Reciter.sudais, speed: 2.0, repeat: 5);
    final changed = base.copyWith(speed: 1.25);
    expect(changed.reciter, Reciter.sudais);
    expect(changed.speed, 1.25);
    expect(changed.repeat, 5);
  });
}
