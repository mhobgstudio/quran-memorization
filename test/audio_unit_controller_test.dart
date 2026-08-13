import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/services/audio_player.dart';
import 'package:quran_memorization/memorization_calc.dart'
    show MemorizationDirection;
import 'package:quran_memorization/services/audio_settings.dart';
import 'package:quran_memorization/services/audio_unit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudio implements QuranAudio {
  final _completed = StreamController<void>();
  List<String>? lastUrls;
  int? lastRepeat;
  double? lastSpeed;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> play({required List<String> urls, required int repeat}) async {
    playCalls++;
    lastUrls = urls;
    lastRepeat = repeat;
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> setSpeed(double speed) async => lastSpeed = speed;

  @override
  Future<void> dispose() async {}

  @override
  Stream<void> get onCompleted => _completed.stream;

  void finish() => _completed.add(null);
}

void main() {
  Future<AudioUnitController> started({_FakeAudio? audio}) async {
    final a = audio ?? _FakeAudio();
    final unit = AudioUnitController(audio: a);
    await unit.play(
      urls: const ['u1', 'u2'],
      label: 'سورة البقرة · page 22',
      settings: 'Husary (murattal) · 1.5× · repeat ×3',
      page: 22,
      linesPerDay: 5,
      direction: MemorizationDirection.backward,
      repeat: 3,
      reciter: Reciter.husary,
      speed: 1.5,
      echo: false,
    );
    return unit;
  }

  test('play starts a unit and exposes mini-player state', () async {
    final audio = _FakeAudio();
    final unit = AudioUnitController(audio: audio);
    expect(unit.hasUnit, isFalse);
    expect(unit.playing, isFalse);

    await unit.play(
      urls: const ['u1', 'u2'],
      label: 'سورة البقرة · page 22',
      settings: 'Husary (murattal) · 1.5× · repeat ×3',
      page: 22,
      linesPerDay: 5,
      direction: MemorizationDirection.backward,
      repeat: 3,
      reciter: Reciter.husary,
      speed: 1.5,
      echo: false,
    );

    expect(unit.playing, isTrue);
    expect(unit.hasUnit, isTrue);
    expect(unit.label, 'سورة البقرة · page 22');
    expect(unit.settings, 'Husary (murattal) · 1.5× · repeat ×3');
    expect(unit.page, 22);
    expect(unit.linesPerDay, 5);
    expect(unit.direction, MemorizationDirection.backward);
    expect(unit.repeat, 3);
    expect(unit.reciter, Reciter.husary);
    expect(unit.speed, 1.5);
    expect(audio.lastUrls, const ['u1', 'u2']);
    expect(audio.lastRepeat, 3);
    expect(audio.lastSpeed, 1.5);
  });

  test('toggle pauses then resumes the unit', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);

    await unit.toggle();
    expect(unit.playing, isFalse);
    expect(audio.pauseCalls, 1);
    expect(unit.hasUnit, isTrue, reason: 'pausing keeps the mini player');

    await unit.toggle();
    expect(unit.playing, isTrue);
    expect(audio.playCalls, 2);
  });

  test('setSpeed applies immediately and notifies', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);
    var notified = 0;
    unit.addListener(() => notified++);

    await unit.setSpeed(2.0);
    expect(unit.speed, 2.0);
    expect(audio.lastSpeed, 2.0);
    expect(notified, 1);

    await unit.setSpeed(2.0);
    expect(notified, 1, reason: 'no-op when unchanged');
  });

  test('stop dismisses the unit', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);

    unit.stop();
    expect(unit.playing, isFalse);
    expect(unit.hasUnit, isFalse);
    expect(audio.stopCalls, 1);
  });

  test('echo mode plays one ayah at a time and auto-pauses', () async {
    final audio = _FakeAudio();
    final unit = AudioUnitController(audio: audio);
    await unit.play(
      urls: const ['u1', 'u2', 'u3'],
      label: 'L',
      settings: 'S',
      page: 1,
      linesPerDay: 5,
      direction: MemorizationDirection.forward,
      repeat: 3,
      reciter: Reciter.alafasy,
      speed: 1.0,
      echo: true,
    );
    expect(unit.echo, isTrue);
    expect(audio.lastUrls, const ['u1']);
    expect(unit.ayahIndex, 0);
    expect(unit.totalAyahs, 3);

    // Ayah 1 finishes -> auto-pause, next is ayah 2.
    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(unit.playing, isFalse);
    expect(unit.ayahIndex, 1);
    expect(unit.hasUnit, isTrue, reason: 'mini player stays dismissible');

    await unit.toggle();
    expect(audio.lastUrls, const ['u2']);

    audio.finish();
    await Future<void>.delayed(Duration.zero);
    await unit.toggle();
    expect(audio.lastUrls, const ['u3']);

    // After the last ayah it wraps to the first.
    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(unit.ayahIndex, 0);
  });

  test('echo degrades infinite repeat to a single play per ayah', () async {
    final audio = _FakeAudio();
    final unit = AudioUnitController(audio: audio);
    await unit.play(
      urls: const ['u1', 'u2'],
      label: 'L',
      settings: 'S',
      page: 1,
      linesPerDay: 5,
      direction: MemorizationDirection.forward,
      repeat: 0,
      reciter: Reciter.alafasy,
      speed: 1.0,
      echo: true,
    );
    expect(audio.lastUrls, const ['u1']);
    expect(audio.lastRepeat, 1);
  });

  test('setEcho stops a playing unit and flips the mode', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);
    expect(unit.echo, isFalse);
    expect(unit.playing, isTrue);

    await unit.setEcho(true);
    expect(unit.echo, isTrue);
    expect(unit.playing, isFalse);
    expect(audio.pauseCalls, 1);
  });

  test('unit completion clears the playing state', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);

    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(unit.playing, isFalse);
    expect(unit.hasUnit, isTrue, reason: 'the mini player stays dismissible');
  });

  test('initializes defaults from AudioSettings', () {
    final unit = AudioUnitController(
      audio: _FakeAudio(),
      settings: const AudioSettings(
        reciter: Reciter.sudais,
        speed: 2.0,
        repeat: 5,
      ),
    );
    expect(unit.reciter, Reciter.sudais);
    expect(unit.speed, 2.0);
    expect(unit.repeat, 5);
    unit.dispose();
  });

  test('saveDefaults updates the getters and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final unit = AudioUnitController(audio: _FakeAudio());

    await unit.saveDefaults(
      reciter: Reciter.minshawi,
      speed: 0.75,
      repeat: 0,
    );

    expect(unit.reciter, Reciter.minshawi);
    expect(unit.speed, 0.75);
    expect(unit.repeat, 0);

    final loaded = await AudioSettings.load();
    expect(loaded.reciter, Reciter.minshawi);
    expect(loaded.speed, 0.75);
    expect(loaded.repeat, 0);
    unit.dispose();
  });

  test('saveDefaults with nulls keeps the current values', () async {
    SharedPreferences.setMockInitialValues({});
    final unit = AudioUnitController(
      audio: _FakeAudio(),
      settings: const AudioSettings(reciter: Reciter.husary, speed: 1.5),
    );

    await unit.saveDefaults(repeat: 5);

    expect(unit.reciter, Reciter.husary);
    expect(unit.speed, 1.5);
    expect(unit.repeat, 5);
    unit.dispose();
  });
  test('liveSettings reflects reciter, speed, repeat and echo live', () async {
    final unit = await started();  // husary, 1.5x, repeat 3
    expect(
      unit.liveSettings,
      'Husary (murattal) · 1.5× · repeat ×3',
    );

    await unit.setSpeed(0.75);
    expect(unit.liveSettings, 'Husary (murattal) · 0.75× · repeat ×3');

    await unit.setEcho(true);
    expect(unit.liveSettings, 'Husary (murattal) · 0.75× · repeat ×3 · echo');

    SharedPreferences.setMockInitialValues({});
    await unit.saveDefaults(reciter: Reciter.sudais, repeat: 0);
    expect(unit.liveSettings, 'Sudais · 0.75× · repeat ∞ · echo');
  });
}
