#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>

// Definición de la estructura FP (Fixed Point) del juego
struct FP {
    int64_t _serializedValue;
};

// Helper to convert float to FP (assuming 32 fractional bits based on dump.cs MAX_VALUE)
// dump.cs says FRACTIONAL_PLACES = 32. ONE = 4294967296 (2^32).
static inline struct FP FloatToFP(float value) {
    struct FP fp;
    fp._serializedValue = (int64_t)(value * 4294967296.0f);
    return fp;
}

static inline float FPToFloat(struct FP value) {
    return (float)value._serializedValue / 4294967296.0f;
}

#endif
