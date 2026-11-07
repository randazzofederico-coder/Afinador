# 🎵 Afinador — Musical Instrument Tuner

A real-time chromatic instrument tuner built with **Flutter**. Captures audio from the microphone, detects the fundamental pitch using the YIN algorithm, identifies the closest musical note, and displays the deviation in cents — all with a sleek dark-mode UI. Part of the [Saroo Apps](https://federicorandazzo.com.ar/apps/) ecosystem for musicians.

**Current version: 1.2.0** (build 9, `pubspec.yaml` → `version: 1.2.0+9`). Web: [federicorandazzo.com.ar/afinador/](https://federicorandazzo.com.ar/afinador/) · Android: `com.saroo.afinador`.

---

## 🆕 What's new in 1.2.0 (Novedades)

- **Ecosystem account in Settings** — first section, `AccountSection(hasLibrary: false)`: optional Google sign-in shared with the other apps and the website. The Afinador has no library, so nothing is synced.
- **Other apps suggestion** — after good usage (≥ 5 different days or ≥ 30 min tuning) a one-time sheet suggests the other apps, shown only in quiet moments: entering Settings or pausing the mic with the FAB. Rate-limited by the package (max. one suggestion per session/day, 14-day cooldown, 3 times max).
- **"More apps" section** in Settings with the other ecosystem apps (real icons, "Beta" tag, links by status).
- **Local usage stats** (`UsageTracker`): opens, active days, foreground minutes and tuning time, stored only on the device (nothing is sent anywhere).
- **Portrait lock on phone web** (`PortraitOnly`): on phones the web version always stays vertical; in landscape a "Rotate your phone" notice covers the app without re-laying it out. Tablets, desktop and native apps are unaffected.
- **Legacy login removed** — the old login/`AuthGate` (dead code) is gone; the app opens straight on the tuner.

All of the above comes from the shared [`fede_apps_core`](https://github.com/randazzofederico-coder/fede_apps_core) package (see [Ecosystem integration](#-ecosystem-integration-fede_apps_core)).

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

### 🔐 Account

> [!NOTE]
> The app needs no account: it starts directly on the tuner (`main.dart` → `TunerScreen`) and works fully offline.

Optional **ecosystem account** (shared with the other Saroo apps and the website) from the [`fede_apps_core`](https://github.com/randazzofederico-coder/fede_apps_core) package (v0.5.1):

- **Settings → Account** (first section) shows `AccountSection(hasLibrary: false)`: "Continue with Google" when signed out; name/email and "Sign out" when signed in.
- Google only: popup on web, `google_sign_in` on Android. On first sign-in the package creates the `users/{uid}` profile (same format as the site) in Firebase project `federicorandazzo-a5c9b`.
- The Afinador has **no library**, so nothing is synced (no `LibrarySync`/adapter): the account is identity only.
- `main.dart` calls `FedeAccount.instance.init()` after `Firebase.initializeApp` (guarded, never blocks startup). `firebase_auth`, `cloud_firestore` and `google_sign_in` come transitively from the package.
- **Shared session with the website:** the web build uses the same Firebase web config as the site (see [Firebase configuration](#firebase-configuration)), so signing in on federicorandazzo.com.ar also signs in the web Afinador and vice versa.

### 🌱 Ecosystem integration (`fede_apps_core`)

| Piece | Where | What it does in the Afinador |
|---|---|---|
| `UsageTracker` | `main.dart` (`init()`, guarded), `AudioTunerService` | Local-only usage stats (SharedPreferences, `fac_usage_*`). "Activity" = mic listening: `startActivity()` when the stream starts, `stopActivity()` on stop, stream error/close and dispose. Does not continue in background (the mic is released). |
| `EcosystemPrompts.maybeShowAppsPrompt` | `SettingsScreen.initState` (post-frame) and the FAB when pausing the mic | Suggests the other apps only after good usage and never while the mic is on; frequency limited by `PromptGate`. |
| `EcosystemSection` | Settings → **More apps** | Metrónomo, Atril, Generador de Tonos with real icon, "Beta" tag and tagline. `showSite: false` (the site is already linked from About). |
| `AccountSection` / `FedeAccount` | Settings → **Account** | See above. |
| `PortraitOnly` | `MaterialApp.builder` | Phone web always vertical (`backgroundColor: 0xFF121212`). |

Ecosystem texts come from `FacStrings` (Spanish / English, like the app).

### 📱 Platform Features
| Feature | Description |
|---|---|
| **Keep Screen On** | Prevent the device from sleeping while tuning (toggleable, enabled by default) |
| **Microphone selection** | Choose specific input devices on desktop/web platforms with real-time volume gauge |
| **PWA support** | Installable Progressive Web App with native-like experience, auto-detection of install capability, and manual install instructions for unsupported browsers |
| **Web splash screen** | Web/PWA shows a branded loading screen (dark background + app icon) until Flutter renders its first frame, matching the Android app bundle |
| **Portrait on phone web** | `PortraitOnly` (`fede_apps_core`) keeps the web version vertical on phones (shortest side < 600); landscape shows a "Rotate your phone" notice and the UI is never re-laid out |
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
├── settings_screen.dart          # Language, reference pitch, transposition, wakelock, mic selection, sample rate, PWA install, about + forum
├── settings_repository.dart      # SharedPreferences singleton: app language (+ one-time cleanup of legacy login keys)
├── locale_controller.dart        # Selected app language (null = follow system)
├── l10n/                         # ARB translations (es, en) + generated AppLocalizations
├── firebase_options.dart         # Firebase configuration (auto-generated, gitignored)
├── pwa_install_service.dart      # Cross-platform PWA install orchestrator
├── pwa_install_stub.dart         # No-op stub for non-web platforms
└── pwa_install_web.dart          # Web-specific beforeinstallprompt handler
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

### Key Classes

| Class | Responsibility |
|---|---|
| `AudioTunerService` | Records the audio stream (serialized start/stop/restart), manages the ring buffer, runs the DSP pipeline, verifies the sample rate, persists tuner settings via SharedPreferences |
| `YinPitchDetector` | Allocation-free YIN with early exit and parabolic interpolation |
| `TunerResult` | Immutable data class holding note, frequencies, cents, `centsHistory` and parallel `noteHistory` |
| `TunerScreen` | Main UI — note, frequencies, gauge and sismograph via `ValueListenableBuilder`; releases/rebuilds the mic on app lifecycle changes |
| `TunerIndicatorPainter` | `CustomPainter` for the horizontal cents gauge with color-coded needle (= newest history point) |
| `SismographPainter` | `CustomPainter` for the pitch-history trace: monotone cubic curve, cut on note change, gradient coloring and fade-out |
| `SettingsRepository` | Singleton over SharedPreferences: app language; removes legacy login keys on startup |
| `LocaleController` | Holds the selected `Locale` (or `null` for system) and persists it; `MaterialApp` rebuilds on change |
| `AppLocalizations` | Generated from the ARB files; provides every UI string |
| `PwaInstallService` | Captures `beforeinstallprompt` on web, provides install/installed state via ValueNotifiers |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.10.4)
- [`fede_apps_core`](https://github.com/randazzofederico-coder/fede_apps_core) cloned **next to** this repo (`pubspec.yaml` uses `path: ../fede_apps_core`)
- A physical device with a microphone (emulators may not support real-time audio input)
- `lib/firebase_options.dart` (not versioned, see [Firebase configuration](#firebase-configuration))

### Installation

```bash
# Clone both repositories side by side (e.g. C:\dev\Afinador and C:\dev\fede_apps_core)
git clone https://github.com/randazzofederico-coder/fede_apps_core.git
git clone https://github.com/randazzofederico-coder/Afinador.git
cd Afinador

# Install dependencies
flutter pub get

# Run on a connected device
flutter run
```

> After updating `fede_apps_core`, run `flutter pub get` again: the package version is recorded in `pubspec.lock` (currently 0.5.1). To build without the sibling folder (CI, another machine) replace the path dependency with `git: { url: https://github.com/randazzofederico-coder/fede_apps_core.git, ref: v0.5.1 }`.

### Firebase configuration

`lib/firebase_options.dart`, `android/app/google-services.json` and the iOS/macOS `GoogleService-Info.plist` are **gitignored**. Project: `federicorandazzo-a5c9b` (`firebase.json` holds the FlutterFire mapping).

> [!IMPORTANT]
> The **web** config in `firebase_options.dart` must use the **same `apiKey` / `appId` as the website** so the session is shared (Firebase stores the session per `apiKey`):
>
> ```dart
> static const FirebaseOptions web = FirebaseOptions(
>   apiKey: 'AIzaSyB-J7F5pH90Zmk5VZ1jdsoPQvrNwPgy_f4',
>   appId: '1:858245145787:web:9f041f6423348bca05b59e',
>   // messagingSenderId, projectId: 'federicorandazzo-a5c9b',
>   // authDomain: 'federicorandazzo-a5c9b.firebaseapp.com', storageBucket: as generated
> );
> ```
>
> `flutterfire configure` regenerates the file with the app's own web app (`firebase.json` points to a different web `appId`). **If you regenerate it, put these two values back.**

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle (Play Store)
flutter build appbundle --release

# Web (as deployed: served from /afinador/)
flutter build web --wasm --base-href "/afinador/"
```

**Web deploy:** done from the website repo (`mi-web-fede/deploy.ps1`, option **2 – Afinador**): it runs the build above in `C:\dev\Afinador`, mirrors `build/web` into `public/afinador/`, builds the Astro site (which copies it to `dist/afinador/`) and replaces only that folder on the server.

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
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | ^2.3.0 | Persistent settings |
| [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) | ^1.2.8 | Screen wake lock management |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | ^1.0.8 | iOS-style icons |
| [`firebase_core`](https://pub.dev/packages/firebase_core) | ^3.12.1 | Firebase initialization |
| [`url_launcher`](https://pub.dev/packages/url_launcher) | ^6.3.1 | Opening external links (website, forum) |
| [`fede_apps_core`](https://github.com/randazzofederico-coder/fede_apps_core) | path `../fede_apps_core` (0.5.1) | Shared ecosystem code: account, usage stats, other-apps suggestion, "More apps", portrait lock on phone web. Brings `firebase_auth`, `cloud_firestore`, `google_sign_in` transitively |
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
7. **FAB button** — Toggle microphone on/off (turning it on fully restarts the audio engine; pausing it is a "quiet moment" where the other-apps suggestion may appear)

### Settings Screen

Opening Settings is also a "quiet moment": the other-apps suggestion may appear on top (only with good usage, rate-limited).

Sections, top to bottom:

- **Account** — Optional ecosystem account (Google sign-in / sign out), from `fede_apps_core`
- **Language** — System language (default) / Español / English
- **Reference pitch** (400–480 Hz) with ± buttons
- **Instrument transposition** dropdown (C, Bb, Eb, F, etc.)
- **Keep screen on** toggle
- **Microphone selection** (desktop/web only) with volume indicator
- **Sample rate** — Effective capture rate in use
- **PWA install** section (web only)
- **More apps** — The other ecosystem apps (`fede_apps_core`)
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

> Fine-tuning: the main knobs (`_smoothingMs`, `_confirmMs`, `_releaseGateRatio`, `_peakDecayMs`) are grouped in the `TUNING KNOBS` block of `lib/audio_tuner_service.dart`. See [ARCHITECTURE.md](ARCHITECTURE.md#tuning-knobs).

---

## 📄 License

This project is for personal/educational use.
