import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'yin_pitch_detector.dart';

// Web-only: detects the browser's real capture sample rate.
import 'sample_rate_probe_stub.dart'
    if (dart.library.js_interop) 'sample_rate_probe_web.dart';

// kIsWeb is available via package:flutter/foundation.dart

class TunerResult {
  final String note;
  final double currentHz;
  final double targetHz;
  final int cents;
  final List<double> centsHistory;
  /// MIDI note each [centsHistory] point is measured against (same length and
  /// order). A change between neighbours means the line must be cut there.
  final List<int> noteHistory;

  TunerResult({
    required this.note,
    required this.currentHz,
    required this.targetHz,
    required this.cents,
    required this.centsHistory,
    this.noteHistory = const [],
  });
}

class AudioTunerService {
  // Not final: restart() disposes it and creates a fresh one, so any broken
  // native state (e.g. after another app grabbed the mic) is discarded.
  AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;

  // Serializes start/stop/restart so lifecycle events fired in quick
  // succession never interleave with each other.
  Future<void> _opChain = Future.value();

  // Incremented on every start/stop. Callbacks from an old session
  // (stream events, in-flight isolate results) are ignored.
  int _sessionId = 0;
  bool _disposed = false;

  /// Rate requested on native platforms (Android/iOS deliver it exactly).
  static const int defaultSampleRate = 44100;
  /// Analysis window. Must stay this long to detect low notes (~45 Hz).
  static const int bufferSize = 2048;
  /// A new reading is computed every [hopSize] samples (50% overlap), i.e.
  /// ~43 readings/s, so fresh data never waits a full window to be analyzed.
  static const int hopSize = 1024;
  /// Points kept in the history line (~2.8 s at ~43 readings/s).
  static const int historyLength = 120;
  static const String _pitchPrefKey = "reference_pitch";
  static const String _keepScreenOnKey = "keep_screen_on";
  static const String _transpositionKey = "transposition";
  static const String _selectedDeviceIdKey = "selected_device_id";

  // --- Sample rate verification ---
  // A wrong sample rate shifts every detected pitch by the same ratio
  // (e.g. 48000 vs 44100 = ~147 cents, almost a semitone and a half).
  // Besides asking for the right rate, we measure how many samples per
  // second really arrive and correct the rate if it doesn't match.
  static const List<int> _standardRates = [
    8000, 11025, 16000, 22050, 24000, 32000, 44100, 48000, 88200, 96000,
  ];
  static const int _rateWarmupMs = 1000; // ignore startup bursts
  static const int _rateFirstCheckMs = 3000;
  static const int _rateCheckIntervalMs = 2000;
  static const double _rateSnapTolerance = 0.02; // ±2%

  final Stopwatch _rateClock = Stopwatch();
  int _rateSamples = 0;
  bool _rateWarm = false;
  int _nextRateCheckMs = _rateFirstCheckMs;
  int? _rateCandidate;
  int _rateCandidateHits = 0;

  /// Sample rate currently used to convert detected periods into Hz.
  final ValueNotifier<int> effectiveSampleRate = ValueNotifier(defaultSampleRate);
  
  final ValueNotifier<double> referencePitch = ValueNotifier(440.0);
  final ValueNotifier<bool> keepScreenOn = ValueNotifier(true);
  final ValueNotifier<int> transposition = ValueNotifier(0);
  final ValueNotifier<InputDevice?> selectedDevice = ValueNotifier(null);
  final ValueNotifier<List<InputDevice>> availableDevices = ValueNotifier([]);
  final ValueNotifier<double> currentVolume = ValueNotifier(0.0);

  final ValueNotifier<bool> isRecording = ValueNotifier(false);
  
  AudioTunerService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPitch = prefs.getDouble(_pitchPrefKey);
    if (savedPitch != null) {
      referencePitch.value = savedPitch;
    }

    final savedScreenOn = prefs.getBool(_keepScreenOnKey);
    if (savedScreenOn != null) {
      keepScreenOn.value = savedScreenOn;
    } else {
      keepScreenOn.value = true;
    }
    _applyWakelock(keepScreenOn.value);

    final savedTransposition = prefs.getInt(_transpositionKey);
    if (savedTransposition != null) {
      transposition.value = savedTransposition;
    }

    // Load saved device ID (will be matched when devices are listed)
    final savedDeviceId = prefs.getString(_selectedDeviceIdKey);
    if (savedDeviceId != null) {
      // We store the ID; we'll match it to a real InputDevice when listing
      _pendingSavedDeviceId = savedDeviceId;
    }
  }

  String? _pendingSavedDeviceId;

  void _applyWakelock(bool enable) {
    try {
      if (enable) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (e) {
      // WakelockPlus may not fully support web — fail silently
      debugPrint('WakelockPlus error (expected on web): $e');
    }
  }

  Future<void> setReferencePitch(double pitch) async {
    referencePitch.value = pitch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pitchPrefKey, pitch);
  }

  Future<void> setKeepScreenOn(bool value) async {
    keepScreenOn.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenOnKey, value);
    _applyWakelock(value);
  }

  Future<void> setTransposition(int transpose) async {
    transposition.value = transpose;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_transpositionKey, transpose);
  }

  /// Lists available audio input devices.
  /// On web and desktop this returns connected microphones.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      final devices = await _audioRecorder.listInputDevices();
      availableDevices.value = devices;

      // If we had a saved device ID, try to match it
      if (_pendingSavedDeviceId != null) {
        final match = devices.where((d) => d.id == _pendingSavedDeviceId);
        if (match.isNotEmpty) {
          selectedDevice.value = match.first;
        }
        _pendingSavedDeviceId = null;
      }

      return devices;
    } catch (e) {
      debugPrint('Error listing input devices: $e');
      return [];
    }
  }

  /// Sets the selected audio input device.
  /// Pass null to use the system default.
  Future<void> setSelectedDevice(InputDevice? device) async {
    selectedDevice.value = device;
    final prefs = await SharedPreferences.getInstance();
    if (device != null) {
      await prefs.setString(_selectedDeviceIdKey, device.id);
    } else {
      await prefs.remove(_selectedDeviceIdKey);
    }

    // If currently recording, restart with the new device
    if (isRecording.value) {
      await restart();
    }
  }
  
  final ValueNotifier<TunerResult> resultNotifier = ValueNotifier(
    TunerResult(
      note: "--",
      currentHz: 0.0,
      targetHz: 0.0,
      cents: 0,
      centsHistory: [],
    )
  );

  final List<String> _noteNames = ["C", "Db/C#", "D", "Eb/D#", "E", "F", "Gb/F#", "G", "Ab/G#", "A", "Bb/A#", "B"];
  
  // Ring buffer for audio (avoids memory allocation inside the listener loop)
  final Float64List _audioBuffer = Float64List(bufferSize * 2); 
  int _bufferIndex = 0;
  int _samplesCount = 0; // samples received since the last analysis
  int _samplesFilled = 0; // valid samples in the ring (capped at bufferSize)
  final Float64List _analysisWindow = Float64List(bufferSize);
  final YinPitchDetector _yin = YinPitchDetector(bufferSize);

  // ===================== TUNING KNOBS (all in ms) =====================
  // Everything is tracked as a continuous MIDI number (semitones) instead of
  // cents-from-nearest-note, so crossing a note boundary (+49 -> -49 cents)
  // doesn't make the smoothing sweep through 0 and fake an "in tune" moment.
  //
  // Smoothing of needle + history line while a note is sustained.
  // Higher = calmer but more delay. Lower = faster but more jittery.
  static const double _smoothingMs = 70;
  // How long a new note must stay steady before it's shown.
  // Higher = steadier note changes. Lower = reacts faster to a new note.
  static const double _confirmMs = 60;
  // Release gate: when the level drops below this fraction of the note's
  // recent peak, the note is considered finished and the tail is ignored.
  // Higher = cuts the release earlier. Lower = shows more of the release.
  static const double _releaseGateRatio = 0.25; // ≈ -12 dB
  // How fast that "recent peak" forgets (lets naturally decaying notes,
  // like a guitar string, keep being shown).
  static const double _peakDecayMs = 200;
  // =====================================================================

  // Median of the last 3 readings removes isolated wrong detections.
  static const int _medianSize = 3;
  // Readings further apart than this are unrelated (silence in between).
  static const double _gapResetMs = 250;
  // Jumps bigger than this are treated as a possible note change.
  static const double _snapSemitones = 0.5;
  // Below this level (≈ -60 dBFS) there's nothing worth analyzing.
  static const double _minRms = 0.001;

  final List<double> _recentMidi = [];
  final List<double> _pendingMidi = [];
  double _pendingMs = 0;
  double _msSinceLastPitch = double.infinity;
  double _peakRms = 0;
  double? _smoothedMidi;
  final List<double> _centsHistory = [];
  final List<int> _noteHistory = [];

  // Android: deliver audio in small chunks (1024 samples ≈ 23 ms) instead of
  // the default (often ~80 ms). Disabled automatically if a device rejects it.
  static const int _androidStreamBufferBytes = 2048;
  bool _androidSmallBufferUnsupported = false;
  // Web: AudioWorklet chunk size in frames (≈ 11 ms at 48 kHz; default 2048).
  static const int _webStreamBufferFrames = 512;

  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      // On web, permission_handler is not supported.
      // The record package handles getUserMedia permissions internally.
      return await _audioRecorder.hasPermission();
    } else {
      // Native platforms: use permission_handler
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        return await _audioRecorder.hasPermission();
      }
      return false;
    }
  }

  /// Runs [op] after every previously queued start/stop/restart has finished.
  Future<void> _serialize(Future<void> Function() op) {
    final completer = Completer<void>();
    _opChain = _opChain.then((_) async {
      try {
        await op();
        completer.complete();
      } catch (e) {
        // Logged and swallowed: callers (lifecycle, buttons) fire-and-forget.
        debugPrint("Tuner operation failed: $e");
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> start() => _serialize(_startInternal);

  Future<void> stop() => _serialize(_stopInternal);

  /// Fully reboots the audio engine: releases the mic, throws away the native
  /// recorder, creates a new one, re-checks permissions and starts streaming.
  /// Meant to be called every time the app comes back to the foreground.
  Future<void> restart() => _serialize(() async {
        await _stopInternal();
        if (_disposed) return;

        try {
          await _audioRecorder.dispose();
        } catch (e) {
          debugPrint("Error disposing recorder: $e");
        }
        _audioRecorder = AudioRecorder();

        resultNotifier.value = TunerResult(
          note: "--",
          currentHz: 0.0,
          targetHz: 0.0,
          cents: 0,
          centsHistory: [],
        );
        _applyWakelock(keepScreenOn.value);

        await _startInternal();
      });

  Future<void> _startInternal() async {
    if (_disposed || isRecording.value) return;
    
    final hasPerm = await requestPermissions();
    if (_disposed) return;
    if (!hasPerm) {
      debugPrint("Microphone permission denied.");
      return;
    }

    // On web, use the browser's real capture rate so record_web streams it
    // untouched instead of running it through its (lossy) resampler.
    int rate = defaultSampleRate;
    if (kIsWeb) {
      final probed =
          await probeCaptureSampleRate(deviceId: selectedDevice.value?.id);
      if (_disposed) return;
      if (probed != null) rate = probed;
    }
    effectiveSampleRate.value = rate;
    debugPrint("Tuner sample rate: $rate Hz");

    // Smaller chunks = audio reaches the analyzer sooner.
    // (Units differ per platform: frames on web, bytes on Android.)
    int? streamBufferSize;
    final bool usingSmallAndroidBuffer = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_androidSmallBufferUnsupported;
    if (kIsWeb) {
      streamBufferSize = _webStreamBufferFrames;
    } else if (usingSmallAndroidBuffer) {
      streamBufferSize = _androidStreamBufferBytes;
    }

    try {
      final stream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: rate,
          numChannels: 1,
          device: selectedDevice.value,
          // Any browser/OS voice processing can distort the waveform.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          streamBufferSize: streamBufferSize,
        ),
      );
      if (_disposed) return;

      _resetDspState();
      final session = ++_sessionId;
      bool gotData = false;

      // If the small Android buffer is rejected, the recorder fails right
      // away (before any audio). Remember that and reboot with the default.
      bool fallBackIfSmallBufferFailed() {
        if (gotData || !usingSmallAndroidBuffer) return false;
        debugPrint("Small Android buffer not supported, using default.");
        _androidSmallBufferUnsupported = true;
        restart();
        return true;
      }

      _recordSub = stream.listen(
        (data) {
          if (session != _sessionId) return;
          gotData = true;
          _handleAudioData(data);
        },
        onError: (Object e) {
          debugPrint("Audio stream error: $e");
          if (session != _sessionId || _disposed) return;
          if (fallBackIfSmallBufferFailed()) return;
          isRecording.value = false;
          currentVolume.value = 0.0;
        },
        onDone: () {
          // The native side closed the stream (e.g. mic taken by another app).
          if (session != _sessionId || _disposed) return;
          if (fallBackIfSmallBufferFailed()) return;
          isRecording.value = false;
          currentVolume.value = 0.0;
        },
        cancelOnError: true,
      );

      isRecording.value = true;
    } catch (e) {
      debugPrint("Error starting tuner: $e");
      if (usingSmallAndroidBuffer && !_disposed) {
        _androidSmallBufferUnsupported = true;
        restart();
      }
    }
  }

  Future<void> _stopInternal() async {
    _sessionId++; // invalidate callbacks from the current session

    final sub = _recordSub;
    _recordSub = null;
    try {
      await sub?.cancel();
    } catch (e) {
      debugPrint("Error cancelling audio subscription: $e");
    }

    // Actually release the microphone at the native level.
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint("Error stopping recorder: $e");
    }

    _resetDspState();
    if (!_disposed) {
      isRecording.value = false;
      currentVolume.value = 0.0;
    }
  }

  void _resetDspState() {
    _bufferIndex = 0;
    _samplesCount = 0;
    _samplesFilled = 0;
    _smoothedMidi = null;
    _recentMidi.clear();
    _pendingMidi.clear();
    _pendingMs = 0;
    _msSinceLastPitch = double.infinity;
    _peakRms = 0;
    _centsHistory.clear();
    _noteHistory.clear();
    _audioBuffer.fillRange(0, _audioBuffer.length, 0.0);

    _rateClock
      ..stop()
      ..reset();
    _rateSamples = 0;
    _rateWarm = false;
    _nextRateCheckMs = _rateFirstCheckMs;
    _rateCandidate = null;
    _rateCandidateHits = 0;
  }

  /// Measures how many samples per second really arrive and, if that clearly
  /// matches a different standard rate than the one we assume, switches to it.
  ///
  /// Catches cases where the platform silently delivers another rate than
  /// requested (e.g. iOS Safari keeping a stale 48 kHz after the hardware
  /// moved to 44.1 kHz), which would otherwise detune every reading.
  void _trackSampleRate(int samples) {
    if (!_rateClock.isRunning) {
      // First chunk: its samples were captured before t=0, so don't count it.
      _rateClock.start();
      return;
    }

    if (!_rateWarm) {
      if (_rateClock.elapsedMilliseconds < _rateWarmupMs) return;
      // Startup bursts (pre-buffered audio) are over: measure from here.
      _rateWarm = true;
      _rateClock.reset();
      _rateSamples = 0;
      return;
    }

    _rateSamples += samples;
    final elapsedMs = _rateClock.elapsedMilliseconds;
    if (elapsedMs < _nextRateCheckMs) return;
    _nextRateCheckMs += _rateCheckIntervalMs;

    // Cumulative average: the longer it runs, the less timing jitter matters.
    final measured = _rateSamples * 1000.0 / elapsedMs;
    final snapped = _snapToStandardRate(measured);
    if (snapped == null) return; // too irregular to draw conclusions

    if (snapped == effectiveSampleRate.value) {
      _rateCandidate = null;
      _rateCandidateHits = 0;
      return;
    }

    // Require two consecutive agreeing measurements before switching.
    if (snapped == _rateCandidate) {
      _rateCandidateHits++;
    } else {
      _rateCandidate = snapped;
      _rateCandidateHits = 1;
    }
    if (_rateCandidateHits >= 2) {
      debugPrint(
        "Sample rate mismatch: assumed ${effectiveSampleRate.value} Hz, "
        "measured ${measured.toStringAsFixed(0)} Hz -> using $snapped Hz",
      );
      effectiveSampleRate.value = snapped;
      _rateCandidate = null;
      _rateCandidateHits = 0;
    }
  }

  int? _snapToStandardRate(double measured) {
    for (final rate in _standardRates) {
      if ((measured / rate - 1).abs() <= _rateSnapTolerance) return rate;
    }
    return null;
  }

  void _handleAudioData(Uint8List data) {
    // Read from bytes directly via ByteData to avoid loop memory allocations
    final byteData = ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
    
    double sumSquares = 0.0;
    
    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      int sample = byteData.getInt16(i, Endian.little);
      double normalized = sample / 32768.0;
      
      sumSquares += normalized * normalized;
      
      _audioBuffer[_bufferIndex] = normalized;
      
      _bufferIndex = (_bufferIndex + 1) % _audioBuffer.length;
      _samplesCount++;
    }

    // Update volume level
    final int sampleCount = byteData.lengthInBytes ~/ 2;
    _trackSampleRate(sampleCount);
    if (sampleCount > 0) {
      final double rms = sqrt(sumSquares / sampleCount);
      // Amplify visually and cap at 1.0
      double displayVolume = rms * 5.0; 
      if (displayVolume > 1.0) displayVolume = 1.0;
      
      // Smooth the volume for the UI
      currentVolume.value = currentVolume.value * 0.7 + displayVolume * 0.3;
    }

    // Analyze as soon as a new hop of audio is in (window overlaps the
    // previous one), instead of waiting for a whole new window.
    _samplesFilled = min(bufferSize, _samplesFilled + sampleCount);
    if (_samplesCount >= hopSize && _samplesFilled >= bufferSize) {
      final double dtMs = _samplesCount * 1000.0 / effectiveSampleRate.value;
      _samplesCount = 0;
      _analyzeLatestWindow(dtMs);
    }
  }

  /// Runs pitch detection on the newest [bufferSize] samples.
  /// [dtMs] is the audio time elapsed since the previous analysis.
  void _analyzeLatestWindow(double dtMs) {
    // Copy the ring buffer in chronological order. The level used by the
    // release gate is measured on the newest hop only, so it reacts fast.
    double recentSumSquares = 0.0;
    int readIndex = (_bufferIndex - bufferSize + _audioBuffer.length) % _audioBuffer.length;
    for (int i = 0; i < bufferSize; i++) {
      final double v = _audioBuffer[readIndex];
      _analysisWindow[i] = v;
      if (i >= bufferSize - hopSize) recentSumSquares += v * v;
      readIndex = (readIndex + 1) % _audioBuffer.length;
    }
    final double rms = sqrt(recentSumSquares / hopSize);

    _msSinceLastPitch += dtMs;

    // Release gate: a note's level falling well below its recent peak means
    // it was stopped/damped. Its tail (often drifting in pitch) is ignored.
    _peakRms = max(rms, _peakRms * exp(-dtMs / _peakDecayMs));
    if (rms < _minRms || rms < _peakRms * _releaseGateRatio) {
      _recentMidi.clear();
      _pendingMidi.clear();
      _pendingMs = 0;
      return;
    }

    // Synchronous: the early-exit YIN is cheap (~0.1–2 ms), and skipping the
    // isolate spawn per reading removes several ms of latency.
    final double pitch =
        _yin.detect(_analysisWindow, effectiveSampleRate.value.toDouble());
    if (pitch > 20.0 && pitch < 4000.0) {
      _updatePitch(pitch, dtMs);
    }
  }

  void _updatePitch(double pitchInHz, double dtMs) {
    final double ref = referencePitch.value;
    final double rawMidi = 12 * (log(pitchInHz / ref) / ln2) + 69;

    // After a silence, start fresh (old readings say nothing about this one).
    if (_msSinceLastPitch > _gapResetMs) {
      _recentMidi.clear();
      _pendingMidi.clear();
      _pendingMs = 0;
    }
    _msSinceLastPitch = 0;

    // 1) Median of the last 3 readings: removes isolated wrong detections
    //    (octave errors, transients) without averaging them into the curve.
    _recentMidi.add(rawMidi);
    if (_recentMidi.length > _medianSize) _recentMidi.removeAt(0);
    final double midi =
        _recentMidi.length < _medianSize ? rawMidi : _median(_recentMidi);

    final double? previous = _smoothedMidi;
    final double smoothed;
    if (previous != null && (midi - previous).abs() <= _snapSemitones) {
      // 2a) Same note: time-based exponential smoothing, so it feels the
      //     same regardless of how often a device delivers readings.
      _pendingMidi.clear();
      _pendingMs = 0;
      final double alpha = 1 - exp(-dtMs / _smoothingMs);
      smoothed = previous + (midi - previous) * alpha;
    } else {
      // 2b) Big jump (new note, attack transient, or first sound after
      //     silence). Don't show it until it holds steady for [_confirmMs];
      //     meanwhile needle and history keep their last value.
      if (_pendingMidi.isNotEmpty &&
          (midi - _pendingMidi.first).abs() > _snapSemitones) {
        _pendingMidi.clear(); // still wandering: start over
      }
      if (_pendingMidi.isEmpty) {
        _pendingMs = 0;
      } else {
        _pendingMs += dtMs;
      }
      _pendingMidi.add(midi);
      if (_pendingMs < _confirmMs) return;
      smoothed = _median(_pendingMidi);
      _pendingMidi.clear();
      _pendingMs = 0;
    }
    _smoothedMidi = smoothed;

    // 3) Needle, note name and history line all use this same value.
    final int midiNote = smoothed.round();
    final double targetHz = ref * pow(2.0, (midiNote - 69) / 12.0);
    final double cents = (smoothed - midiNote) * 100;
    
    _centsHistory.insert(0, cents);
    _noteHistory.insert(0, midiNote);
    if (_centsHistory.length > historyLength) {
      _centsHistory.removeLast();
      _noteHistory.removeLast();
    }

    final int transposedMidiNote = midiNote - transposition.value;
    final int noteIndex = (transposedMidiNote % 12 + 12) % 12; // Aseguramos que sea positivo
    final String noteName = _noteNames[noteIndex];
    final int octave = (transposedMidiNote ~/ 12) - 1;

    resultNotifier.value = TunerResult(
      note: "$noteName$octave",
      currentHz: pitchInHz,
      targetHz: targetHz,
      cents: cents.round(),
      centsHistory: List.from(_centsHistory),
      noteHistory: List.from(_noteHistory),
    );
  }

  /// Median of a window (for even sizes, the upper-middle value), so the
  /// result is always a real reading, never an average.
  static double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void dispose() {
    _disposed = true;
    _sessionId++;
    _recordSub?.cancel();
    _recordSub = null;
    _audioRecorder.dispose();
    isRecording.dispose();
    currentVolume.dispose();
    resultNotifier.dispose();
    selectedDevice.dispose();
    availableDevices.dispose();
    effectiveSampleRate.dispose();
  }
}

