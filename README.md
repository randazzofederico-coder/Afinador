# 🎵 Afinador — Musical Instrument Tuner

A real-time chromatic instrument tuner built with **Flutter**. Captures audio from the microphone, detects the fundamental pitch using the YIN algorithm, identifies the closest musical note, and displays the deviation in cents — all with a sleek dark-mode UI. Part of the [Saroo Apps](https://federicorandazzo.com.ar/apps/) ecosystem for musicians.

---

## ✨ Features

### 🎤 Core Tuning
| Feature | Description |
|---|---|
| **Real-time pitch detection** | Listens to the microphone and detects the fundamental frequency with an in-house, allocation-free YIN implementation (`YinPitchDetector`) |
| **Note identification** | Maps the detected frequency to the nearest note (C0–B8) using MIDI math, with enharmonic display (e.g. `Db/C#`) |
| **Instrument Transposition** | Automatically offsets readings for transposing instruments (Bb clarinet/trumpet/tenor sax, Eb alto/bari sax, F horn, etc.) |
| **Custom A4 Pitch** | Configurable reference pitch (400–480 Hz, e.g. 432 Hz, 442 Hz) with persistent storage |
| **Cents gauge** | Custom-painted horizontal gauge showing deviation from perfect pitch (−50 to +50 cents). The needle is always the newest point of the history line |
| **Sismograph history** | Scrolling trace of the last 120 readings (~2.8 s) with a color gradient (green → amber → red), monotone cubic interpolation (passes through every reading, no overshoot) and a cut whenever the note changes |
| **Stable note changes** | A new note is only shown once it holds steady for 60 ms; attack transients and release tails are filtered out |

### ⚡ Performance & Accuracy
| Feature | Description |
|---|---|
| **Low latency (~110–140 ms)** | Small audio chunks, analysis every 1024 samples (50 % overlap) and synchronous early-exit YIN (≤ 2.4 ms) — no isolate spawn per reading |
| **Time-based smoothing** | Median of 3 + exponential smoothing with a 70 ms time constant, in a continuous MIDI domain (no fake "in tune" sweep across note boundaries) |
| **Release gate** | Ignores the tail of a note once its level falls below 25 % of its recent peak |
| **Verified sample rate** | On web the real capture rate is probed (no lossy resampling); on every platform the actual samples/second are measured and corrected if they don't match |
| **Mic lifecycle** | The mic is released when the app goes to background and the audio engine is fully rebuilt on return |
| **Ring buffer** | A `Float64List` ring buffer accumulates PCM samples without allocations in the hot path |
| **Volume monitoring** | Real-time RMS-based microphone activity indicator with smoothed output |

> See [ARCHITECTURE.md](ARCHITECTURE.md) for the full pipeline, tuning knobs and platform details.

### 🔐 Authentication & Access

> [!NOTE]
> **Currently not in use.** The app starts directly on the tuner (`main.dart` → `TunerScreen`). The auth code below (`auth_gate.dart`, `login_screen.dart`, `onboarding_screen.dart`) is kept in the repo for possible future use but is not wired in.

| Feature | Description |
|---|---|
| **Firebase Authentication** | Secure login with Google Sign-In and email/password, with platform-aware support (Google Sign-In on Android/iOS/Web only) |
| **Firestore access control** | Role-based permissions via `usuarios/{uid}` documents with subscription and trial tracking |
| **Offline login** | After first successful login, permissions are cached locally (SharedPreferences) for 30 days. The app works fully offline without re-authentication |
| **Offline warning banner** | Orange gradient banner appears when ≤5 days remain before revalidation is needed |
| **Trial system** | 30-day free trial with admin notifications, subscription redirect, and pending access screen |
| **Onboarding flow** | New users fill out a profile form; admin is notified automatically via `consultas_web` |
| **Network error handling** | Login screen detects offline state via string-based error matching (avoids `dart:io` for web compatibility) and shows clear messages |

### 📱 Platform Features
| Feature | Description |
|---|---|
| **Keep Screen On** | Prevent the device from sleeping while tuning (toggleable, enabled by default) |
| **Microphone selection** | Choose specific input devices on desktop/web platforms with real-time volume gauge |
| **PWA support** | Installable Progressive Web App with native-like experience, auto-detection of install capability, and manual install instructions for unsupported browsers |
| **Web splash screen** | Web/PWA shows a branded loading screen (dark background + app icon) until Flutter renders its first frame, matching the Android app bundle |
| **Multi-language** | Spanish and English. Follows the system language on first launch (falls back to Spanish) and can be changed from the top of Settings. App name: *Afinador* (es) / *Tuner* (en) |
| **Community forum** | Quick access from Settings → About to the [Saroo forum](https://federicorandazzo.com.ar/foro/) for questions and suggestions |

---

## 🌐 Localization

Built with Flutter's official `flutter_localizations` + ARB files (`gen_l10n`).

| File | Purpose |
|---|---|
| `l10n.yaml` | Generator config (template: `app_es.arb`) |
| `lib/l10n/app_es.arb` | Spanish strings (source of truth) |
| `lib/l10n/app_en.arb` | English strings |
| `lib/l10n/app_localizations*.dart` | Generated code — do not edit by hand |
| `lib/locale_controller.dart` | `ValueNotifier<Locale?>` with the user's choice (`null` = system language) |

- **Usage in widgets:** `AppLocalizations.of(context).someKey`
- **Edit a translation:** change the `.arb` file and run `flutter pub get` (or any build/run) to regenerate.
- **Add a language:** create `lib/l10n/app_<code>.arb` with the same keys and add its native name to `_languageNames` in `settings_screen.dart`.
- **Persistence:** the choice is stored in SharedPreferences under `app_locale` (removed when "System language" is selected).
- **Note names** always use English notation (C, D, E…) in every language.
- **Native app name:** Android uses `res/values/strings.xml` (Afinador) and `res/values-en/strings.xml` (Tuner). The web manifest and iOS (PWA) keep the Spanish name.
- **Docs:** privacy policy in `privacidad.md` / `privacy.md`; store description in `descripcion.md` / `description.md`.

---

## 📱 Supported Platforms

- ✅ Android (APK + App Bundle)
- ✅ iOS
- ✅ Web (PWA)
- ✅ Windows
- ✅ Linux
- ✅ macOS

---

## 🏗️ Architecture

> Detailed technical documentation: **[ARCHITECTURE.md](ARCHITECTURE.md)**

```
lib/
├── main.dart                     # App entry, TunerScreen UI + lifecycle, CustomPainters (gauge + sismograph)
├── audio_tuner_service.dart      # Audio engine: recorder lifecycle, ring buffer, DSP pipeline, settings
├── yin_pitch_detector.dart       # Allocation-free YIN pitch detector with early exit
├── sample_rate_probe_web.dart    # Web: probes the browser's real capture sample rate
├── sample_rate_probe_stub.dart   # No-op probe for non-web platforms
├── auth_gate.dart                # (not in use) Firebase auth stream, Firestore permission checker, offline fallback
├── login_screen.dart             # (not in use) Email/password + Google login with network error handling
├── onboarding_screen.dart        # (not in use) New user profile form → Firestore
├── settings_screen.dart          # Language, reference pitch, transposition, wakelock, mic selection, sample rate, PWA install, about + forum
├── settings_repository.dart      # SharedPreferences singleton: app language + permission cache
├── locale_controller.dart        # Selected app language (null = follow system)
├── l10n/                         # ARB translations (es, en) + generated AppLocalizations
├── firebase_options.dart         # Firebase configuration (auto-generated, gitignored)
├── pwa_install_service.dart      # Cross-platform PWA install orchestrator
├── pwa_install_stub.dart         # No-op stub for non-web platforms
├── pwa_install_web.dart          # Web-specific beforeinstallprompt handler
└── models/
    └── permission_cache.dart     # Cached permission state with 30-day expiry logic
```

### Data Flow — Tuning

```
Microphone (PCM 16-bit mono · 44100 Hz native / real browser rate on web · small chunks)
    │
    ▼
Ring Buffer (Float64List, 4096 samples) + sample-rate verifier
    │  every 1024 new samples → newest 2048 samples
    ▼
Release gate (level vs. decaying peak)  ──► YinPitchDetector (sync)  ──► frequency (Hz)
    │
    ▼
_updatePitch()   (continuous MIDI domain)
    ├── median of 3 readings
    ├── same note  → time-based EMA (70 ms)
    ├── new note   → shown after 60 ms steady
    ├── note name + octave (with transposition), cents
    └── ValueNotifier<TunerResult> (+ centsHistory / noteHistory)  →  UI rebuild
```

### Data Flow — Authentication & Offline Access (not in use)

```
App Launch
    │
    ▼
Firebase Auth → ¿hay User local?
    NO → LoginScreen (requiere internet)
    SÍ ↓
    ▼
Firestore check (Source.server, fuerza servidor)
    OK → guardar cache local (SharedPreferences) + TunerScreen
    FAIL (sin internet) ↓
    ▼
¿Hay cache local?
    NO → "Conexión necesaria" (primera vez)
    SÍ ↓
    ▼
¿Cache < 30 días? + ¿hasAccess?
    SÍ → TunerScreen (si ≤5 días → banner naranja)
    NO → "Sesión expirada, conectate"
```

### Key Classes

| Class | Responsibility |
|---|---|
| `AudioTunerService` | Records the audio stream (serialized start/stop/restart), manages the ring buffer, runs the DSP pipeline, verifies the sample rate, persists tuner settings via SharedPreferences |
| `YinPitchDetector` | Allocation-free YIN with early exit and parabolic interpolation |
| `TunerResult` | Immutable data class holding note, frequencies, cents, `centsHistory` and parallel `noteHistory` |
| `TunerScreen` | Main UI — note, frequencies, gauge and sismograph via `ValueListenableBuilder`; releases/rebuilds the mic on app lifecycle changes |
| `TunerIndicatorPainter` | `CustomPainter` for the horizontal cents gauge with color-coded needle (= newest history point) |
| `SismographPainter` | `CustomPainter` for the pitch-history trace: monotone cubic curve, cut on note change, gradient coloring and fade-out |
| `SettingsRepository` | Singleton over SharedPreferences: app language and permission cache (save/load/clear) |
| `LocaleController` | Holds the selected `Locale` (or `null` for system) and persists it; `MaterialApp` rebuilds on change |
| `AppLocalizations` | Generated from the ARB files; provides every UI string |
| `PermissionCache` | Model with 30-day expiry calculation, warning thresholds, and access state |
| `AuthGate` | StreamBuilder on auth state → routes to Login, Onboarding, Permission checker, or Tuner |
| `_PermissionChecker` | Firestore permission check with offline fallback, cache management, and state routing |
| `PwaInstallService` | Captures `beforeinstallprompt` on web, provides install/installed state via ValueNotifiers |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.10.4)
- A physical device with a microphone (emulators may not support real-time audio input)
- Firebase project configured (see `firebase_options.dart`)

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

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle (Play Store)
flutter build appbundle --release

# Web
flutter build web
```

### Permissions

The app requests microphone access at runtime via `permission_handler`. Platform-specific declarations are already configured:

- **Android**: `RECORD_AUDIO` in `AndroidManifest.xml`
- **iOS**: `NSMicrophoneUsageDescription` in `Info.plist`
- **Web**: Handled automatically by the `record` package via `getUserMedia`

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| [`record`](https://pub.dev/packages/record) | ^6.2.0 | Cross-platform audio recording (PCM stream) |
| [`permission_handler`](https://pub.dev/packages/permission_handler) | ^12.0.1 | Runtime permission management |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | ^2.3.0 | Persistent settings & permission cache |
| [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) | ^1.2.8 | Screen wake lock management |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | ^1.0.8 | iOS-style icons |
| [`firebase_core`](https://pub.dev/packages/firebase_core) | ^3.12.1 | Firebase initialization |
| [`firebase_auth`](https://pub.dev/packages/firebase_auth) | ^5.5.1 | Firebase authentication (not in use) |
| [`cloud_firestore`](https://pub.dev/packages/cloud_firestore) | ^5.6.5 | NoSQL cloud database for permissions (not in use) |
| [`google_sign_in`](https://pub.dev/packages/google_sign_in) | ^6.2.2 | Google Authentication provider (not in use) |
| [`url_launcher`](https://pub.dev/packages/url_launcher) | ^6.3.1 | Opening external links (website, forum) |
| [`flutter_localizations`](https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html) | SDK | Localized Material/Cupertino widgets + generated `AppLocalizations` |
| [`intl`](https://pub.dev/packages/intl) | any (pinned by Flutter SDK) | Message formatting for translations |

---

## 🎨 UI Overview

The app uses a **dark theme** (`Color(0xFF121212)`) with Material 3. The main screen displays:

1. **Note name** — Large bold text (e.g., `A4`) with transposition applied
2. **Current frequency** — Detected Hz value
3. **Reference frequency** — Target Hz for the closest note
4. **A4 reference** — Configurable base pitch displayed in AppBar and main screen
5. **Cents gauge** — Horizontal bar with color-coded needle (always equal to the newest history point):
   - 🟢 Green: ≤ 5 cents (in tune)
   - 🟡 Amber: ≤ 20 cents (close)
   - 🔴 Red: > 20 cents (out of tune)
6. **Sismograph** — Historical trace with monotone cubic interpolation, a new segment per note, and gradient fade-out
7. **FAB button** — Toggle microphone on/off (turning it on fully restarts the audio engine)

### Authentication Screens (not in use)

| Screen | When shown |
|---|---|
| `LoginScreen` | No authenticated user. Google + email/password login |
| `OnboardingScreen` | User exists but no Firestore profile. Collects name + interest |
| `_PendingAccessScreen` | Profile exists but no subscription/trial/admin role |
| `_NeedsInternetScreen` | Offline with no cache, expired cache, or no access in cache |
| `_OfflineWarningWrapper` | Offline with valid cache but ≤5 days remaining |
| `_TrialBannerWrapper` | Active trial period with days remaining counter |

### Settings Screen

Sections, top to bottom:

- **Language** — System language (default) / Español / English (first, so it's always easy to find)
- **Reference pitch** (400–480 Hz) with ± buttons
- **Instrument transposition** dropdown (C, Bb, Eb, F, etc.)
- **Keep screen on** toggle
- **Microphone selection** (desktop/web only) with volume indicator
- **Sample rate** — Effective capture rate in use
- **PWA install** section (web only)
- **About** — Links to [federicorandazzo.com.ar/apps/](https://federicorandazzo.com.ar/apps/) and the community [forum](https://federicorandazzo.com.ar/foro/)

---

## 🛠️ Technical Details

| Parameter | Value |
|---|---|
| **Sample rate** | 44,100 Hz native · browser's real capture rate on web · live-verified on all platforms |
| **Analysis window / hop** | 2,048 samples window, new reading every 1,024 samples (~23 ms at 44.1 kHz) |
| **Stream chunks** | Web 512 frames · Android 2,048 bytes (automatic fallback to default) · iOS native default |
| **Pitch detector** | YIN, threshold 0.20, early exit, parabolic interpolation |
| **Smoothing** | Median of 3 + time-based EMA (70 ms); note changes confirmed after 60 ms |
| **Release gate** | Level < 25 % of decaying peak (200 ms) ends the note |
| **Estimated latency** | ~110–140 ms (sound → screen) |
| **History** | Last 120 readings (~2.8 s) displayed in the sismograph |
| **Frequency range** | 20 Hz – 4,000 Hz (filters out noise/harmonics) |
| **Offline cache** | 30-day expiry, warning at ≤5 days (auth flow, not in use) |
| **Auth cache storage** | SharedPreferences (8 keys for permission state, auth flow, not in use) |

> Fine-tuning: the main knobs (`_smoothingMs`, `_confirmMs`, `_releaseGateRatio`, `_peakDecayMs`) are grouped in the `TUNING KNOBS` block of `lib/audio_tuner_service.dart`. See [ARCHITECTURE.md](ARCHITECTURE.md#tuning-knobs).

---

## 🔒 Offline Access Details (auth flow, not in use)

> The tuner itself needs no account or connection. This section only applies if the auth flow is re-enabled.

After the first successful online login, the app caches the user's permission state locally:

- **What's cached**: `hasAccess`, `hasProfile`, `rol`, trial state (active/days/expired/used), and `lastVerified` timestamp
- **Expiry**: 30 days from last online verification
- **Warning**: Orange banner when ≤5 days remain
- **Logout**: Clears the cache completely, requiring online re-authentication
- **Firestore reads**: Always use `Source.server` to prevent Firestore's own cache from masking connectivity issues
- **Error detection**: String-based matching (`socketexception`, `failed host lookup`, etc.) instead of `dart:io` imports to maintain web compatibility

---

## 📄 License

This project is for personal/educational use.
