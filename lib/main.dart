import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'audio_tuner_service.dart';

void main() {
  runApp(const AfinadorApp());
}

class AfinadorApp extends StatelessWidget {
  const AfinadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afinador Musical',
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

class _TunerScreenState extends State<TunerScreen> {
  final AudioTunerService _tunerService = AudioTunerService();

  @override
  void initState() {
    super.initState();
    // Start listening on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tunerService.start();
    });
  }

  @override
  void dispose() {
    _tunerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Afinador'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                    const SizedBox(height: 2),
                    Text(
                      "Ref: ${result.targetHz.toStringAsFixed(1)} Hz",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Visual Indicator Gauge
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 40,
                      height: 50,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: result.cents.toDouble()),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedCents, child) {
                          return CustomPaint(
                            painter: TunerIndicatorPainter(animatedCents),
                          );
                        },
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
                            painter: SismographPainter(result.centsHistory),
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
                _tunerService.stop();
              } else {
                _tunerService.start();
              }
            },
            backgroundColor: Colors.blueAccent,
            child: Icon(isRec ? Icons.mic : Icons.mic_off, color: Colors.white),
          );
        },
      ),
    );
  }

  Color _getCentsColor(double cents) {
    if (cents.abs() <= 5) return Colors.greenAccent;
    if (cents.abs() <= 20) return Colors.amber;
    return Colors.redAccent;
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

  SismographPainter(this.history);

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
    final maxItems = 60;
    final pointSpacing = usableHeight / maxItems;

    // Build the curve points
    final List<Offset> points = [];
    for (int i = 0; i < history.length; i++) {
        final double cents = history[i].clamp(-50.0, 50.0);
        final x = center + (cents / 50.0) * (size.width / 2);
        final y = 5.0 + i * pointSpacing;
        points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        // Use mid-point bezier curve for smooth interpolation
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        
        if (i == points.length - 2) {
           path.lineTo(p1.dx, p1.dy); // attach to last point
        }
      }
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
}
