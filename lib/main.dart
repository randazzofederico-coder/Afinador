import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'audio_tuner_service.dart';
import 'settings_screen.dart';
import 'pwa_install_service.dart';
import 'settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize settings repository (SharedPreferences) for offline access cache
  await SettingsRepository.instance.init();
  // Initialize PWA install prompt capture (web only, no-op on other platforms)
  PwaInstallService().initialize();
  runApp(const AfinadorApp());
}

class AfinadorApp extends StatelessWidget {
  const AfinadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afinador Musical',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const TunerScreen(),
    );
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  final AudioTunerService _tunerService = AudioTunerService();

  // True when the user turned the mic off with the button; in that case we
  // don't auto-start it again when the app comes back to the foreground.
  bool _userStopped = false;
  // True once the app actually left the foreground (paused/hidden).
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start listening on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tunerService.start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // The tuner is useless in background: release the mic so other apps
        // can use it and we don't end up holding a dead/silenced stream.
        if (!_inBackground) {
          _inBackground = true;
          _tunerService.stop();
        }
        break;
      case AppLifecycleState.resumed:
        // Back in foreground: reboot the engine from scratch (new recorder,
        // permission re-check, fresh stream) instead of trusting old state.
        if (_inBackground) {
          _inBackground = false;
          if (!_userStopped) {
            _tunerService.restart();
          }
        }
        break;
      case AppLifecycleState.inactive:
        // Ignored on purpose: the permission dialog, notification shade and
        // app switcher trigger this without the app really leaving.
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tunerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<double>(
          valueListenable: _tunerService.referencePitch,
          builder: (context, refPitch, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Afinador'),
                Text(
                  'A4 = ${refPitch.toInt()} Hz',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(tunerService: _tunerService),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _tunerService.isRecording,
        builder: (context, isRecording, _) {
          if (!isRecording) {
            return const Center(
              child: Text(
                "Esperando micrófono...",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ValueListenableBuilder<TunerResult>(
            valueListenable: _tunerService.resultNotifier,
            builder: (context, result, _) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Note display
                    Text(
                      result.note,
                      style: const TextStyle(
                        fontSize: 80, // Smaller font
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Frequencies display
                    Text(
                      "${result.currentHz.toStringAsFixed(1)} Hz",
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Visual Indicator Gauge
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 40,
                      height: 50,
                      // No extra animation: the needle shows exactly the
                      // newest point of the history line (same value, same time).
                      child: CustomPaint(
                        painter: TunerIndicatorPainter(
                          result.centsHistory.isNotEmpty
                              ? result.centsHistory.first
                              : result.cents.toDouble(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Sismograph/History
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 40,
                          child: CustomPaint(
                            painter: SismographPainter(
                              result.centsHistory,
                              result.noteHistory,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _tunerService.isRecording,
        builder: (context, isRec, _) {
          return FloatingActionButton(
            onPressed: () {
              if (isRec) {
                _userStopped = true;
                _tunerService.stop();
              } else {
                _userStopped = false;
                _tunerService.restart();
              }
            },
            backgroundColor: Colors.blueAccent,
            child: Icon(isRec ? Icons.mic : Icons.mic_off, color: Colors.white),
          );
        },
      ),
    );
  }
}

class TunerIndicatorPainter extends CustomPainter {
  final double cents;
  
  TunerIndicatorPainter(this.cents);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.grey[850]!;
    final radius = Radius.circular(8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), radius), bgPaint);

    final center = size.width / 2;
    // We reserve the bottom 20 pixels for text
    final gaugeHeight = size.height - 20;
    
    // Center line (Perfect pitch 0 cents)
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(center, 0), Offset(center, gaugeHeight), linePaint);
    
    // Marks and Texts
    final markPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5;
      
    for (int i = -50; i <= 50; i += 10) {
      final x = center + (i / 50.0) * (size.width / 2);
      
      if (i != 0) {
        final yStart = 0.0;
        final yEnd = gaugeHeight;
        canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), markPaint);
      }
      
      // Draw text label
      final textSpan = TextSpan(
        text: i.toString(),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(x - textPainter.width / 2, gaugeHeight + 4)
      );
    }

    // Determine color
    Color needleColor = Colors.redAccent;
    if (cents.abs() <= 5) {
      needleColor = Colors.greenAccent;
    } else if (cents.abs() <= 20) {
      needleColor = Colors.amber;
    }

    // Needle based on cents
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
      
    final c = cents.clamp(-50.0, 50.0);
    final needleX = center + (c / 50.0) * (size.width / 2);
    
    canvas.drawLine(Offset(needleX, -5), Offset(needleX, gaugeHeight + 5), needlePaint);
  }

  @override
  bool shouldRepaint(covariant TunerIndicatorPainter oldDelegate) {
    return oldDelegate.cents != cents;
  }
}

class SismographPainter extends CustomPainter {
  final List<double> history;
  /// Note of each history point; the line is cut wherever it changes.
  final List<int> notes;

  SismographPainter(this.history, this.notes);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    
    final center = size.width / 2;
    
    // Draw centerline
    final centerLinePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), centerLinePaint);

    final path = Path();
    // Leave some padding at the top and bottom
    final usableHeight = size.height - 10;
    final maxItems = AudioTunerService.historyLength;
    final pointSpacing = usableHeight / maxItems;

    // Build the points, cutting into a new segment on every note change:
    // each segment is measured against its own note, so joining them with a
    // line would draw a jump that never happened.
    final hasNotes = notes.length == history.length;
    final List<List<Offset>> segments = [];
    List<Offset> current = [];
    for (int i = 0; i < history.length; i++) {
        if (hasNotes && i > 0 && notes[i] != notes[i - 1]) {
          segments.add(current);
          current = [];
        }
        final double cents = history[i].clamp(-50.0, 50.0);
        final x = center + (cents / 50.0) * (size.width / 2);
        final y = 5.0 + i * pointSpacing;
        current.add(Offset(x, y));
    }
    segments.add(current);

    for (final segment in segments) {
      _addMonotoneCurve(path, segment, pointSpacing);
    }

    // Gradient that maps X coordinate to color
    final shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, 0),
      [
        Colors.redAccent.withOpacity(0.8),
        Colors.amber.withOpacity(0.9),
        Colors.greenAccent,
        Colors.greenAccent,
        Colors.amber.withOpacity(0.9),
        Colors.redAccent.withOpacity(0.8),
      ],
      [
        0.0,  // -50 cents
        0.3,  // -20 cents
        0.45, // -5 cents
        0.55, // 5 cents
        0.7,  // 20 cents
        1.0,  // 50 cents
      ],
    );
    
    final linePaint = Paint()
      ..shader = shader
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    // Draw the curve directly to canvas
    canvas.drawPath(path, linePaint);

    // Fade out mask using a solid gradient overlay exactly matching the background
    // This removes the need for expensive saveLayer masking routines.
    final fadeOutPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [Colors.transparent, const Color(0xFF121212)],
        [0.0, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fadeOutPaint);
  }

  @override
  bool shouldRepaint(covariant SismographPainter oldDelegate) {
    return true; 
  }

  /// Appends one independent sub-path through [points].
  ///
  /// Monotone cubic interpolation (Steffen, 1990) converted to Béziers.
  /// - Passes exactly through every measured point.
  /// - Never overshoots: no peak/valley is drawn that isn't in the data
  ///   (local extrema get a vertical tangent, so they land on a sample).
  /// - O(n) with one cubicTo per segment: as cheap as the old curve.
  ///
  /// Y (time) is uniformly spaced, so X (cents) is a function of Y and
  /// slopes can be expressed in "pixels per sample".
  static void _addMonotoneCurve(Path path, List<Offset> points, double pointSpacing) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      // Single reading: zero-length line, drawn as a dot by the round cap.
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[0].dx, points[0].dy);
      return;
    }

    final n = points.length;
    final tangents = List<double>.filled(n, 0.0);
    tangents[0] = points[1].dx - points[0].dx;
    tangents[n - 1] = points[n - 1].dx - points[n - 2].dx;
    for (int i = 1; i < n - 1; i++) {
      final dPrev = points[i].dx - points[i - 1].dx;
      final dNext = points[i + 1].dx - points[i].dx;
      if (dPrev * dNext <= 0) {
        tangents[i] = 0.0; // local extremum or flat: no overshoot
      } else {
        final limit = min(min(dPrev.abs(), dNext.abs()), (dPrev + dNext).abs() / 4);
        tangents[i] = 2 * dPrev.sign * limit;
      }
    }

    path.moveTo(points[0].dx, points[0].dy);
    final third = pointSpacing / 3;
    for (int i = 0; i < n - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      path.cubicTo(
        p0.dx + tangents[i] / 3, p0.dy + third,
        p1.dx - tangents[i + 1] / 3, p1.dy - third,
        p1.dx, p1.dy,
      );
    }
  }
}
