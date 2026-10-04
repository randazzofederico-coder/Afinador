# 🏛️ Afinador — Architecture

Technical reference for the tuning engine, the UI that renders it and the platform-specific details that keep it accurate and low-latency. For a feature overview and setup instructions see [README.md](README.md).

---

## 1. Module map

```
lib/
├── main.dart                     # AfinadorApp, TunerScreen (lifecycle), TunerIndicatorPainter, SismographPainter
├── audio_tuner_service.dart      # Audio engine: recorder lifecycle, ring buffer, DSP pipeline, settings
├── yin_pitch_detector.dart       # Allocation-free YIN with early exit (replaces pitch_detector_dart)
├── sample_rate_probe_web.dart    # Web: reads the browser's real capture sample rate (js_interop)
├── sample_rate_probe_stub.dart   # Non-web: no-op probe (returns null)
├── settings_screen.dart          # Reference pitch, transposition, wakelock, mic selection, sample-rate info
├── auth_gate.dart / login_screen.dart / onboarding_screen.dart   # Firebase auth flow
├── settings_repository.dart / models/permission_cache.dart       # Offline permission cache
└── pwa_install_service.dart / pwa_install_web.dart / pwa_install_stub.dart
web/
└── index.html                    # HTML splash screen shown until Flutter's first frame
```

> [!NOTE]
> `AfinadorApp.home` is currently `TunerScreen` directly. `AuthGate` (Firebase login, trial, offline cache) is implemented but not wired as the home route.

---

## 2. Audio pipeline

Everything lives in [`AudioTunerService`](lib/audio_tuner_service.dart). The same value drives the needle, the note name and the history line, so they can never disagree.

```
Microphone ──► record (PCM16 mono, small chunks)
                │
                ▼
_handleAudioData()        int16 → Float64 ring buffer (4096) · RMS volume · sample-rate verifier
                │  every hopSize = 1024 new samples (50 % overlap)
                ▼
_analyzeLatestWindow()    copy newest 2048 samples
                │  release gate: RMS of newest hop < 0.001  or  < 25 % of decaying peak → drop
                ▼
YinPitchDetector.detect() synchronous, ~0.2 ms (A4) … ~2.4 ms (worst case)
                │  20 Hz < f < 4000 Hz
                ▼
_updatePitch()            continuous MIDI number = 12·log2(f / A4) + 69
                ├─ gap > 250 ms → reset (fresh onset)
                ├─ median of last 3 readings (kills octave errors / transients)
                ├─ |Δ| ≤ 0.5 st  → time-based EMA (τ = _smoothingMs)
                └─ |Δ| > 0.5 st  → pending; shown only after steady for _confirmMs
                │
                ▼
TunerResult { note, currentHz, targetHz, cents, centsHistory[120], noteHistory[120] }
                │  ValueNotifier
                ▼
TunerScreen  → needle = centsHistory.first · sismograph = whole history
```

### Why a continuous MIDI domain
Smoothing *cents-from-nearest-note* breaks at note boundaries (+49 → −49 makes the filter sweep through 0 and fake an "in tune" moment). Smoothing the continuous MIDI number and deriving `midiNote = round(smoothed)` / `cents = (smoothed − midiNote)·100` afterwards avoids that.

### Time-based filters
All filters are expressed in milliseconds and use the real audio time between analyses (`dtMs = samples / sampleRate`), so behaviour is identical on devices that deliver readings at different rates. EMA: `alpha = 1 − exp(−dtMs / _smoothingMs)`.

### Release gate
`_peakRms = max(rms, _peakRms · exp(−dtMs / _peakDecayMs))`. When the newest hop falls below `_releaseGateRatio · _peakRms` the note is considered finished and its tail (usually drifting in pitch) is ignored. The decaying peak lets naturally decaying notes (plucked strings) keep being shown.

### Tuning knobs
Block `TUNING KNOBS` in [audio_tuner_service.dart](lib/audio_tuner_service.dart):

| Constant | Default | Raise it → | Lower it → |
|---|---|---|---|
| `_smoothingMs` | 70 | calmer needle/line, more delay | faster, more jitter |
| `_confirmMs` | 60 | steadier note changes | reacts faster to a new note |
| `_releaseGateRatio` | 0.25 (≈ −12 dB) | cuts the release earlier | shows more of the release |
| `_peakDecayMs` | 200 | gate stricter on decaying notes | decaying notes shown longer |

Secondary constants: `_medianSize = 3`, `_gapResetMs = 250`, `_snapSemitones = 0.5`, `_minRms = 0.001`, `bufferSize = 2048` (must stay ≥ 2048 to detect ~45 Hz), `hopSize = 1024`, `historyLength = 120` (~2.8 s).

---

## 3. Latency

| Stage | Before | Now |
|---|---|---|
| Stream chunk | web 2048 frames · Android ~80 ms default | web 512 frames (~11 ms) · Android 2048 bytes (~23 ms) |
| Analysis cadence | one full window (2048) | every hop (1024, ~23 ms) |
| Pitch detection | `compute()` isolate spawn per reading | synchronous early-exit YIN (≤ 2.4 ms) |
| Smoothing | sample-count EMA (α = 0.15) | 70 ms time constant + 60 ms note confirmation |
| **Estimated total** | ~250 ms web / ~450 ms Android | **~110–140 ms** |

- **Android fallback:** if a device rejects the small buffer (stream errors/closes before any data, or `startStream` throws), `_androidSmallBufferUnsupported` is set and the engine restarts with the platform default.
- **iOS:** chunk size is fixed by the native tap; left unchanged.

### `YinPitchDetector`
Own implementation in [yin_pitch_detector.dart](lib/yin_pitch_detector.dart): difference function + cumulative mean normalized difference with **early exit** at the first dip below threshold (0.20), parabolic interpolation, pre-allocated `Float64List`. Verified to return identical results to `pitch_detector_dart` on 200 synthetic cases before the package was removed.

---

## 4. Sample-rate correctness

A wrong sample rate shifts every reading by the same ratio (48000 vs 44100 ≈ 147 cents). Two layers protect against it:

1. **Probe (web only)** — [sample_rate_probe_web.dart](lib/sample_rate_probe_web.dart) opens the selected mic, reads `MediaStreamTrack.getSettings().sampleRate` (fallback: default `AudioContext.sampleRate`) and the recorder is started at exactly that rate. This keeps `record_web` from running its resampler, which resets its state on every chunk and distorts the waveform. Native platforms use 44100 Hz (delivered exactly).
2. **Live verifier** — `_trackSampleRate()` counts samples actually received per second (1 s warm-up, first check at 3 s, then every 2 s, cumulative average). If the measurement snaps (±2 %) to a different standard rate on two consecutive checks, `effectiveSampleRate` is switched. Catches cases like iOS Safari reporting a stale rate.

`effectiveSampleRate` is shown in Settings ("Frecuencia de muestreo"). `autoGain`, `echoCancel` and `noiseSuppress` are explicitly disabled.

---

## 5. Recorder lifecycle

- `start()`, `stop()` and `restart()` are serialized through an op chain (`_serialize`) so rapid lifecycle events never interleave.
- Each session has an id; callbacks from an old session are ignored.
- `stop()` really releases the mic (`AudioRecorder.stop()`).
- `restart()` disposes the native `AudioRecorder`, creates a fresh one, re-checks permission, resets DSP state and starts streaming — this recovers from broken native state (e.g. another app took the mic).
- `_TunerScreenState` (a `WidgetsBindingObserver`):
  - `paused` / `hidden` / `detached` → `stop()`
  - `resumed` → `restart()` unless the user stopped it with the FAB
  - `inactive` → ignored (fires for the permission dialog)
- Stream `onError` / `onDone` update `isRecording` so the UI reflects a lost mic.

---

## 6. UI rendering

### Needle — `TunerIndicatorPainter`
Draws the −50…+50 ¢ gauge. The needle value is `centsHistory.first` (no extra animation layer), so it is always exactly the head of the history line.

### History — `SismographPainter`
- Up to `historyLength` (120) points, newest at the top, fading out with age; colour by deviation (green ≤ 5 ¢, amber ≤ 20 ¢, red > 20 ¢).
- **Monotone cubic interpolation (Steffen)** in `_addMonotoneCurve`: the curve passes through every reading and never overshoots between them (no invented peaks), at the cost of a few multiplications per point.
- **Segmented by note:** `noteHistory` runs parallel to `centsHistory`; wherever the reference note changes the path is cut and a new segment starts in the new note's frame of reference.
- Round joins/caps.

---

## 7. Web / PWA splash

[web/index.html](web/index.html) shows an HTML splash (`#121212` background, app icon 120 px with a soft "breathing" animation, disabled under `prefers-reduced-motion`) from the very first byte. It is removed on Flutter's `flutter-first-frame` event, with a 20 s safety timeout. `html`/`body` background is also `#121212` to avoid a white flash.
