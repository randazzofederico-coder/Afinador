import 'dart:typed_data';

/// YIN pitch detector (de Cheveigné & Kawahara, 2002).
///
/// Same variant and threshold as `pitch_detector_dart` (a TarsosDSP port),
/// so readings are identical, but built for low latency:
/// - Works on [Float64List] (unboxed doubles, much faster than `List<double>`).
/// - Computes the difference function lazily and stops as soon as the first
///   valid period is found. High notes only need a small fraction of the
///   work (A4 at 44.1 kHz: ~100 of 1024 lags).
/// - Cheap enough to run synchronously, so there's no isolate to spawn per
///   reading (that alone cost several ms of latency on mobile).
class YinPitchDetector {
  /// Max aperiodicity accepted as "pitched" (YIN paper: 0.10–0.15; the
  /// previous library used 0.20).
  static const double threshold = 0.20;

  final Float64List _cmnd;

  /// [windowSize] is the full analysis buffer length; lags go up to half.
  YinPitchDetector(int windowSize) : _cmnd = Float64List(windowSize ~/ 2);

  /// Returns the pitch in Hz, or -1 if there's no clear pitch.
  /// [buffer] must contain at least `windowSize` samples.
  double detect(Float64List buffer, double sampleRate) {
    final int half = _cmnd.length;
    final Float64List cmnd = _cmnd;
    cmnd[0] = 1.0;
    double runningSum = 0.0;
    int best = -1;

    for (int tau = 1; tau < half; tau++) {
      // Step 2: difference function d(tau).
      double sum = 0.0;
      for (int i = 0; i < half; i++) {
        final double delta = buffer[i] - buffer[i + tau];
        sum += delta * delta;
      }
      // Step 3: cumulative mean normalized difference d'(tau).
      runningSum += sum;
      cmnd[tau] = runningSum > 0 ? sum * tau / runningSum : 1.0;

      // Step 4: absolute threshold, then walk down to the local minimum.
      if (best == -1) {
        if (tau >= 2 && cmnd[tau] < threshold) best = tau;
      } else if (cmnd[tau] < cmnd[best]) {
        best = tau;
      } else {
        // d'(best + 1) is already computed: refine and stop early.
        return sampleRate / _parabolicInterpolation(best, half);
      }
    }

    if (best == -1) return -1.0;
    return sampleRate / _parabolicInterpolation(best, half);
  }

  /// Step 5: sub-sample refinement of the period around [tau].
  double _parabolicInterpolation(int tau, int length) {
    final Float64List cmnd = _cmnd;
    final int x0 = tau < 1 ? tau : tau - 1;
    final int x2 = tau + 1 < length ? tau + 1 : tau;

    if (x0 == tau) {
      return cmnd[tau] <= cmnd[x2] ? tau.toDouble() : x2.toDouble();
    }
    if (x2 == tau) {
      return cmnd[tau] <= cmnd[x0] ? tau.toDouble() : x0.toDouble();
    }
    final double s0 = cmnd[x0];
    final double s1 = cmnd[tau];
    final double s2 = cmnd[x2];
    final double denominator = 2 * (2 * s1 - s2 - s0);
    if (denominator == 0) return tau.toDouble();
    return tau + (s2 - s0) / denominator;
  }
}
