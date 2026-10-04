import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Returns the sample rate the browser will actually capture at, so the
/// recorder can be asked for exactly that rate and no resampling happens.
///
/// This mirrors what `record_web` does internally: it builds its AudioContext
/// with the mic track's `getSettings().sampleRate` when available, otherwise
/// with the browser's default AudioContext rate (e.g. Firefox). If we request
/// any other rate, record_web resamples inside its AudioWorklet with a
/// resampler that resets its state on every chunk, which slightly detunes
/// the signal and adds glitches at chunk boundaries.
Future<int?> probeCaptureSampleRate({String? deviceId}) async {
  final fromTrack = await _probeTrackSampleRate(deviceId);
  if (fromTrack != null) return fromTrack;
  return _probeDefaultAudioContextRate();
}

bool _isValidRate(int rate) => rate >= 8000 && rate <= 96000;

Future<int?> _probeTrackSampleRate(String? deviceId) async {
  try {
    final navigator = globalContext['navigator'] as JSObject?;
    final mediaDevices = navigator?['mediaDevices'] as JSObject?;
    if (mediaDevices == null) return null;

    // Same processing flags the tuner uses, so the browser picks the same
    // capture path it will use for the real stream.
    final constraints = {
      'audio': {
        'autoGainControl': false,
        'echoCancellation': false,
        'noiseSuppression': false,
        'channelCount': 1,
        if (deviceId != null) 'deviceId': {'exact': deviceId},
      },
    }.jsify()!;

    final stream = await mediaDevices
        .callMethod<JSPromise<JSObject>>('getUserMedia'.toJS, constraints)
        .toDart;
    final tracks =
        stream.callMethod<JSArray<JSObject>>('getAudioTracks'.toJS).toDart;

    try {
      if (tracks.isEmpty) return null;
      final settings = tracks.first.callMethod<JSObject>('getSettings'.toJS);
      final value = settings['sampleRate'];
      if (value == null || !value.isA<JSNumber>()) return null;
      final rate = (value as JSNumber).toDartDouble.round();
      return _isValidRate(rate) ? rate : null;
    } finally {
      // Release the mic right away; the recorder opens its own stream.
      for (final track in tracks) {
        track.callMethod<JSAny?>('stop'.toJS);
      }
    }
  } catch (_) {
    return null;
  }
}

Future<int?> _probeDefaultAudioContextRate() async {
  try {
    var ctor = globalContext['AudioContext'] as JSFunction?;
    ctor ??= globalContext['webkitAudioContext'] as JSFunction?;
    if (ctor == null) return null;

    final ctx = ctor.callAsConstructor<JSObject>();
    final rate = (ctx['sampleRate'] as JSNumber).toDartDouble.round();
    try {
      await ctx.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
    } catch (_) {
      // Ignore: closing a suspended context can fail on some browsers.
    }
    return _isValidRate(rate) ? rate : null;
  } catch (_) {
    return null;
  }
}
