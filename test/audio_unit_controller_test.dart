import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/quran_audio.dart';
import 'package:quran_memorization/services/audio_player.dart';
import 'package:quran_memorization/memorization_calc.dart'
    show MemorizationDirection;
import 'package:quran_memorization/services/audio_unit_controller.dart';

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

  test('unit completion clears the playing state', () async {
    final audio = _FakeAudio();
    final unit = await started(audio: audio);

    audio.finish();
    await Future<void>.delayed(Duration.zero);
    expect(unit.playing, isFalse);
    expect(unit.hasUnit, isTrue, reason: 'the mini player stays dismissible');
  });
}
