// siddefs.h - reSID configuration for Emscripten/WASM build
// Auto-generated from siddefs.h.in with settings for SIDwinder

#ifndef RESID_SIDDEFS_H
#define RESID_SIDDEFS_H

// Compilation configuration.
#define RESID_INLINING 1
#define RESID_INLINE inline
#define RESID_BRANCH_HINTS 1

#define NEW_8580_FILTER 1

// Compiler specifics.
#define HAVE_BOOL 1
#define HAVE_BUILTIN_EXPECT 1
#define HAVE_LOG1P 1

#if HAVE_LOG1P
#define HAS_LOG1P
#endif

// Branch prediction macros, lifted off the Linux kernel.
#if RESID_BRANCH_HINTS && HAVE_BUILTIN_EXPECT
#define likely(x)      __builtin_expect(!!(x), 1)
#define unlikely(x)    __builtin_expect(!!(x), 0)
#else
#define likely(x)      (x)
#define unlikely(x)    (x)
#endif

namespace reSID {

typedef unsigned int reg4;
typedef unsigned int reg8;
typedef unsigned int reg12;
typedef unsigned int reg16;
typedef unsigned int reg24;

typedef int cycle_count;
typedef short short_point[2];
typedef double double_point[2];

enum chip_model { MOS6581, MOS8580 };

enum sampling_method {
    SAMPLE_FAST,
    SAMPLE_INTERPOLATE,
    SAMPLE_RESAMPLE,
    SAMPLE_RESAMPLE_FASTMEM
};

} // namespace reSID

extern "C"
{
#ifndef RESID_VERSION_CC
extern const char* resid_version_string;
#else
const char* resid_version_string = "SIDwinder-reSID";
#endif
}

#endif // not RESID_SIDDEFS_H
