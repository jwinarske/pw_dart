// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// Minimal Dart API DL shims for native code.
// When running inside a Dart VM, the real Dart_PostCObject_DL is resolved
// via Dart_InitializeApiDL. For standalone testing, we provide stubs.

#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Dart CObject types (subset needed for posting events)
typedef enum {
    Dart_CObject_kNull = 0,
    Dart_CObject_kBool = 1,
    Dart_CObject_kInt32 = 2,
    Dart_CObject_kInt64 = 3,
    Dart_CObject_kDouble = 4,
    Dart_CObject_kString = 5,
    Dart_CObject_kArray = 6,
    Dart_CObject_kTypedData = 7,
    Dart_CObject_kExternalTypedData = 8,
    Dart_CObject_kSendPort = 9,
    Dart_CObject_kCapability = 10,
    Dart_CObject_kNativePointer = 11,
} Dart_CObject_Type;

typedef struct _Dart_CObject {
    Dart_CObject_Type type;
    union {
        bool as_bool;
        int32_t as_int32;
        int64_t as_int64;
        double as_double;
        char* as_string;
        struct {
            int length;
            struct _Dart_CObject** values;
        } as_array;
    } value;
} Dart_CObject;

/// Post a CObject to a Dart SendPort. Returns true on success.
/// This is a function pointer that gets set by Dart_InitializeApiDL.
/// For testing without the Dart VM, this can be stubbed.
typedef bool (*Dart_PostCObject_Type)(int64_t port_id, Dart_CObject* message);

/// Global function pointer — set by init, or points to a no-op stub.
extern Dart_PostCObject_Type Dart_PostCObject_DL;

/// Initialize the Dart API DL. Called once from Dart via FFI.
/// @param data The NativeApi.initializeApiDLData pointer from Dart.
/// @return 0 on success.
int pw_dart_init_dart_api_dl(void* data);

#ifdef __cplusplus
}
#endif

