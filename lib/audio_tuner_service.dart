import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TunerResult {
  final String note;
  final double currentHz;
  final double targetHz;
  final int cents;
  final List<double> centsHistory;

  TunerResult({
    required this.note,
    required this.currentHz,
    required this.targetHz,
    required this.cents,
    required this.centsHistory,
  });
}

class _PitchDetectionData {
  final List<double> chunk; // compute needs standard serializable lists or TypedData
  final int sampleRate;
  final int bufferSize;

  _PitchDetectionData(this.chunk, this.sampleRate, this.bufferSize);
}

class AudioTunerService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;

  static const int sampleRate = 44100;
  static const int bufferSize = 2048;
  static const String _pitchPrefKey = "reference_pitch";
  static const String _keepScreenOnKey = "keep_screen_on";
  static const String _transpositionKey = "transposition";
  
  final ValueNotifier<double> referencePitch = ValueNotifier(440.0);
  final ValueNotifier<bool> keepScreenOn = ValueNotifier(true);
  final ValueNotifier<int> transposition = ValueNotifier(0);

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
  }

  void _applyWakelock(bool enable) {
    if (enable) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
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
  int _samplesCount = 0;

  double _smoothedCents = 0.0;
  final List<double> _centsHistory = [];
  bool _isProcessing = false;

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return await _audioRecorder.hasPermission();
    }
    return false;
  }

  Future<void> start() async {
    if (isRecording.value) return;
    
    final hasPerm = await requestPermissions();
    if (!hasPerm) {
      debugPrint("Microphone permission denied.");
      return;
    }

    try {
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _recordSub = stream.listen((data) {
        _handleAudioData(data);
      });

      isRecording.value = true;
    } catch (e) {
      debugPrint("Error starting tuner: $e");
    }
  }

  Future<void> stop() async {
    if (!isRecording.value) return;
    await _recordSub?.cancel();
    isRecording.value = false;
  }

  void _handleAudioData(Uint8List data) {
    // Read from bytes directly via ByteData to avoid loop memory allocations
    final byteData = ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
    
    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      int sample = byteData.getInt16(i, Endian.little);
      _audioBuffer[_bufferIndex] = sample / 32768.0;
      
      _bufferIndex = (_bufferIndex + 1) % _audioBuffer.length;
      _samplesCount++;
    }

    // Process chunk when ready and if Isolate is not busy dropping frames
    if (_samplesCount >= bufferSize && !_isProcessing) {
       _samplesCount = 0;
       
       // Gather the Sequential chunk from our Ring Buffer
       // Float64List is fast to allocate or we could pass standard Float64List directly
       final chunkToProcess = Float64List(bufferSize);
       int readIndex = (_bufferIndex - bufferSize + _audioBuffer.length) % _audioBuffer.length;
       for (int i = 0; i < bufferSize; i++) {
         chunkToProcess[i] = _audioBuffer[readIndex];
         readIndex = (readIndex + 1) % _audioBuffer.length;
       }

       _processChunkInBackgound(chunkToProcess);
    } else if (_samplesCount > bufferSize * 2) {
       // Avoid unbounded sample count if isolate takes too long
       _samplesCount = bufferSize; 
    }
  }

  Future<void> _processChunkInBackgound(Float64List chunk) async {
    _isProcessing = true;
    
    // We send the array to a background compute isolate so pitch detection math
    // Does not block our buttery smooth 60fps UI drawing
    final pitch = await compute(
      _detectPitch, 
      _PitchDetectionData(chunk.toList(growable: false), sampleRate, bufferSize)
    );
    
    if (pitch > 20.0 && pitch < 4000.0) {
      _updatePitch(pitch);
    }
    
    _isProcessing = false;
  }

  // --- Backound Isolate Function ---
  static Future<double> _detectPitch(_PitchDetectionData data) async {
    final pitchDetector = PitchDetector(
      audioSampleRate: data.sampleRate.toDouble(), 
      bufferSize: data.bufferSize,
    );
    final result = await pitchDetector.getPitchFromFloatBuffer(data.chunk);
    if (result.pitched) return result.pitch;
    return -1.0;
  }
  // ---------------------------------

  void _updatePitch(double pitchInHz) {
    final double ref = referencePitch.value;
    final double midiNoteDouble = 12 * (log(pitchInHz / ref) / ln2) + 69;
    final int midiNote = midiNoteDouble.round();

    final double targetHz = ref * pow(2.0, (midiNote - 69) / 12.0);
    final double rawCents = 1200 * (log(pitchInHz / targetHz) / ln2);

    if ((rawCents - _smoothedCents).abs() > 100) {
      _smoothedCents = rawCents; 
    } else {
      _smoothedCents = _smoothedCents * 0.85 + rawCents * 0.15;
    }
    
    _centsHistory.insert(0, _smoothedCents);
    if (_centsHistory.length > 60) {
      _centsHistory.removeLast();
    }

    final int transposedMidiNote = midiNote - transposition.value;
    final int noteIndex = (transposedMidiNote % 12 + 12) % 12; // Aseguramos que sea positivo
    final String noteName = _noteNames[noteIndex];
    final int octave = (transposedMidiNote ~/ 12) - 1;

    resultNotifier.value = TunerResult(
      note: "$noteName$octave",
      currentHz: pitchInHz,
      targetHz: targetHz,
      cents: _smoothedCents.round(),
      centsHistory: List.from(_centsHistory),
    );
  }

  void dispose() {
    _recordSub?.cancel();
    _audioRecorder.dispose();
    isRecording.dispose();
    resultNotifier.dispose();
  }
}

