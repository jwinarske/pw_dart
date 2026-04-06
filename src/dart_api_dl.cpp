// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

#include "dart_api_dl.h"

#include <cstdio>

// Default stub that does nothing (used when not running inside Dart VM)
static bool dart_post_cobject_stub(int64_t port_id, Dart_CObject* message) {
    (void)port_id;
    (void)message;
    return false;
}

// Global function pointer — starts as stub
Dart_PostCObject_Type Dart_PostCObject_DL = dart_post_cobject_stub;

int pw_dart_init_dart_api_dl(void* data) {
    // In a real Dart environment, we'd call Dart_InitializeApiDL(data)
    // which resolves the real function pointers.
    // For now, this is a simplified version.
    // TODO: Link against dart_api_dl.c from the Dart SDK for full support.
    (void)data;
    return 0;
}

