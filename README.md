# 🎵 Afinador — Musical Instrument Tuner

A real-time musical instrument tuner built with **Flutter**. Captures audio from the microphone, detects the fundamental pitch, identifies the closest musical note, and displays the deviation in cents — all with a sleek dark-mode UI.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎤 **Real-time pitch detection** | Listens to the microphone and detects the fundamental frequency using the YIN algorithm (`pitch_detector_dart`) |
| 🎯 **Note identification** | Maps the detected frequency to the nearest note (C0–B8) using MIDI math, with enharmonic display (e.g. `Db/C#`) |
| 🎼 **Instrument Transposition** | Automatically offsets readings for transposing instruments (Bb, Eb, F, etc.) via settings |
| 🎛️ **Custom A4 Pitch** | Configurable reference pitch (e.g., 432 Hz, 442 Hz) with persistent storage |
| 💡 **Keep Screen On** | Prevent the device from sleeping while tuning (toggleable in settings) |
| 📊 **Cents gauge** | Custom-painted horizontal gauge showing deviation from perfect pitch (−50 to +50 cents) |
| 📈 **Sismograph history** | A scrolling waveform trace that records the last ~60 readings with a color gradient (green → amber → red) |
| ⚡ **Background processing** | Pitch detection runs in a Dart `Isolate` via `compute()` to keep the UI at a smooth 60 fps |
| 🔇 **EMA smoothing** | Exponential Moving Average (α = 0.15) dampens jitter; large jumps (>100 cents) bypass the filter for instant response |
| 🔄 **Ring buffer** | A `Float64List` ring buffer accumulates PCM samples without allocations in the hot path |

---

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ Linux
- ✅ macOS

---

## 🏗️ Architecture

```
lib/
├── main.dart                  # App entry point, UI (TunerScreen, TunerIndicatorPainter, SismographPainter)
├── audio_tuner_service.dart   # Audio recording, pitch detection, note calculation, state management
└── settings_screen.dart       # Configuration UI for reference pitch, transposition, and screen lock
```

### Data Flow

```
Microphone (PCM 16-bit, 44100 Hz, mono)
    │
    ▼
Ring Buffer (Float64List, 4096 samples)
    │  extract 2048 samples
    ▼
compute() Isolate  ──► PitchDetector (YIN)  ──► frequency (Hz)
    │
    ▼
_updatePitch()
    ├── MIDI note number  →  note name + octave
    ├── cents = 1200 × log₂(f / f_target)
    ├── EMA smoothing
    └── ValueNotifier<TunerResult>  →  UI rebuild
```

### Key Classes

| Class | Responsibility |
|---|---|
| `AudioTunerService` | Records audio stream, manages ring buffer, spawns isolate for pitch detection, calculates note/cents, manages SharedPreferences |
| `TunerResult` | Immutable data class holding note, frequencies, cents, and history |
| `TunerScreen` | Main UI — displays note, frequencies, gauge, and sismograph using `ValueListenableBuilder` |
| `TunerIndicatorPainter` | `CustomPainter` for the horizontal cents gauge with animated needle |
| `SismographPainter` | `CustomPainter` for the scrolling pitch-history trace with gradient coloring |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.10.4)
- A physical device with a microphone (emulators may not support real-time audio input)

### Installation

```bash
# Clone the repository
git clone https://github.com/randazzofederico-coder/Afinador.git
cd Afinador

# Install dependencies
flutter pub get

# Run on a connected device
flutter run
```

### Permissions

The app requests microphone access at runtime via `permission_handler`. Platform-specific declarations are already configured:

- **Android**: `RECORD_AUDIO` in `AndroidManifest.xml`
- **iOS**: `NSMicrophoneUsageDescription` in `Info.plist`

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| [`record`](https://pub.dev/packages/record) | ^6.2.0 | Cross-platform audio recording (PCM stream) |
| [`pitch_detector_dart`](https://pub.dev/packages/pitch_detector_dart) | ^0.0.7 | Pitch detection algorithm (YIN) |
| [`permission_handler`](https://pub.dev/packages/permission_handler) | ^12.0.1 | Runtime permission management |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | ^2.3.0 | Persistent user settings storage |
| [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) | ^1.2.8 | Screen wake lock management |
| [`ffi`](https://pub.dev/packages/ffi) | ^2.2.0 | Foreign Function Interface utilities |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | ^1.0.8 | iOS-style icons |

---

## 🎨 UI Overview

The app uses a **dark theme** (`Color(0xFF121212)`) with Material 3. The main screen displays:

1. **Note name** — Large bold text (e.g., `A4`)
2. **Current frequency** — Detected Hz value
3. **Reference frequency** — Target Hz for the closest note
4. **Cents gauge** — Horizontal bar with color-coded needle:
   - 🟢 Green: ≤ 5 cents (in tune)
   - 🟡 Amber: ≤ 20 cents (close)
   - 🔴 Red: > 20 cents (out of tune)
5. **Sismograph** — Historical trace with Bézier smoothing and gradient fade-out
6. **FAB button** — Toggle microphone on/off

---

## 🛠️ Technical Details

- **Sample rate**: 44,100 Hz
- **Buffer size**: 2,048 samples (~46 ms per frame)
- **Smoothing**: EMA with α = 0.15, bypass threshold at 100 cents
- **History**: Last 60 readings displayed in the sismograph
- **Frequency range**: 20 Hz – 4,000 Hz (filters out noise/harmonics)

---

## 📄 License

This project is for personal/educational use.
