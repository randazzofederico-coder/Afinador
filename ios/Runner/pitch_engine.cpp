#include <cmath>
#include <vector>
#include <stdint.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

extern "C" {

__attribute__((visibility("default"))) __attribute__((used))
double get_pitch_yin(const double* buffer, int buffer_size, int sample_rate) {
    if (buffer_size == 0) return -1.0;
    
    int half_size = buffer_size / 2;
    
    // Step 0: Apply Hanning window to a local copy
    // This eliminates edge artifacts that cause pitch jitter
    std::vector<double> windowed(buffer_size);
    for (int i = 0; i < buffer_size; i++) {
        double window = 0.5 * (1.0 - cos(2.0 * M_PI * i / (buffer_size - 1)));
        windowed[i] = buffer[i] * window;
    }

    std::vector<double> yin_buffer(half_size, 0.0);

    // Step 1: Difference function
    for (int tau = 1; tau < half_size; tau++) {
        for (int i = 0; i < half_size; i++) {
            double delta = windowed[i] - windowed[i + tau];
            yin_buffer[tau] += delta * delta;
        }
    }

    // Step 2: Cumulative mean normalized difference function
    double running_sum = 0.0;
    yin_buffer[0] = 1.0;
    for (int tau = 1; tau < half_size; tau++) {
        running_sum += yin_buffer[tau];
        if (running_sum == 0.0) {
            yin_buffer[tau] = 1.0;
        } else {
            yin_buffer[tau] = yin_buffer[tau] * (double)tau / running_sum;
        }
    }

    // Step 3: Absolute threshold
    int tau_estimate = -1;
    double threshold = 0.10;
    for (int tau = 2; tau < half_size; tau++) {
        if (yin_buffer[tau] < threshold) {
            // Find local minimum after dipping below threshold
            while (tau + 1 < half_size && yin_buffer[tau + 1] < yin_buffer[tau]) {
                tau++;
            }
            tau_estimate = tau;
            break;
        }
    }

    if (tau_estimate == -1) {
        // Fallback: global minimum
        double min_val = 1.0;
        for (int tau = 2; tau < half_size; tau++) {
            if (yin_buffer[tau] < min_val) {
                min_val = yin_buffer[tau];
                tau_estimate = tau;
            }
        }
        if (min_val > 0.3) { // Too noisy, reject
            return -1.0;
        }
    }

    // Step 4: Parabolic interpolation for sub-sample accuracy
    double better_tau = (double)tau_estimate;
    if (tau_estimate > 0 && tau_estimate < half_size - 1) {
        double s0 = yin_buffer[tau_estimate - 1];
        double s1 = yin_buffer[tau_estimate];
        double s2 = yin_buffer[tau_estimate + 1];
        
        double denom = 2.0 * s1 - s2 - s0;
        if (fabs(denom) > 1e-12) {
            better_tau += 0.5 * (s0 - s2) / denom;
        }
    }

    // Step 5: Convert to Hz
    if (better_tau <= 0.0) return -1.0;
    
    return (double)sample_rate / better_tau;
}

}
