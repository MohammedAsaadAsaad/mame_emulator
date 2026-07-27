import 'dart:typed_data';

import 'package:mp_audio_stream/mp_audio_stream.dart';

/// Streams stereo PCM from libretro into the system audio device.
class ArcadeAudio {
  ArcadeAudio({this.sampleRate = 44100});

  int sampleRate;

  bool _initialized = false;
  bool _playing = false;
  double _volume = 0.85;
  bool _enabled = true;

  AudioStream? _stream;

  /// Scratch buffer reused to avoid per-frame allocations.
  Float32List _floatBuf = Float32List(0);

  bool get isInitialized => _initialized;
  bool get isPlaying => _playing;
  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> initialize({int? rate}) async {
    if (rate != null && rate > 0) sampleRate = rate;
    if (_initialized) return;
    try {
      _stream = getAudioStream();
      _stream!.init(
        sampleRate: sampleRate,
        channels: 2,
        bufferMilliSec: 120,
        waitingBufferMilliSec: 40,
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
      _stream = null;
    }
  }

  /// Re-init if the core reports a different rate after load.
  Future<void> ensureRate(int rate) async {
    if (rate <= 0) return;
    if (!_initialized) {
      await initialize(rate: rate);
      return;
    }
    if (sampleRate == rate) return;
    sampleRate = rate;
    try {
      _stream?.uninit();
    } catch (_) {}
    _initialized = false;
    await initialize(rate: rate);
    if (_playing && _enabled) {
      try {
        _stream?.resume();
      } catch (_) {}
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!_enabled) {
      pause();
    } else if (_playing) {
      resume();
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
  }

  void resume() {
    if (!_initialized || !_enabled) return;
    _playing = true;
    try {
      _stream?.resume();
    } catch (_) {}
  }

  void pause() {
    _playing = false;
  }

  void clear() {
    _playing = false;
  }

  /// Push interleaved stereo Int16 samples from `retro_audio_sample_batch`.
  void pushBatch(Int16List interleavedStereo) {
    if (!_initialized || !_playing || !_enabled) return;
    if (interleavedStereo.isEmpty) return;

    final n = interleavedStereo.length;
    if (_floatBuf.length < n) {
      _floatBuf = Float32List(n);
    }
    final vol = _volume;
    for (var i = 0; i < n; i++) {
      _floatBuf[i] = (interleavedStereo[i] / 32768.0) * vol;
    }
    try {
      _stream!.push(Float32List.sublistView(_floatBuf, 0, n));
    } catch (_) {}
  }

  /// Push one stereo frame from `retro_audio_sample`.
  void pushSample(int left, int right) {
    if (!_initialized || !_playing || !_enabled) return;
    final vol = _volume;
    try {
      _stream!.push(Float32List.fromList([
        (left / 32768.0) * vol,
        (right / 32768.0) * vol,
      ]));
    } catch (_) {}
  }

  Future<void> dispose() async {
    _playing = false;
    try {
      _stream?.uninit();
    } catch (_) {}
    _stream = null;
    _initialized = false;
  }
}
