cmake_minimum_required(VERSION 3.22)
project(pw_dart_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# --- PipeWire dependency ---
find_package(PkgConfig REQUIRED)
pkg_check_modules(PIPEWIRE REQUIRED libpipewire-0.3>=0.3.40)

# --- Glaze (header-only JSON library) ---
include(FetchContent)
FetchContent_Declare(
  glaze
  GIT_REPOSITORY https://github.com/stephenberry/glaze.git
  GIT_TAG        v4.2.2
  GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(glaze)

# --- Source files ---
set(PW_DART_SOURCES
    pw_dart_native.cpp
    client.cpp
    registry_monitor.cpp
    event_serializer.cpp
    param_handler.cpp
    link_manager.cpp

    dart_api_dl.cpp
)

set(PW_DART_HEADERS
    pw_dart_native.h
    client.hpp
    registry_monitor.hpp
    command_queue.hpp
    event_serializer.hpp
    param_handler.hpp
    link_manager.hpp
    dart_api_dl.h
)

# --- Shared library target ---
add_library(pw_dart_native SHARED ${PW_DART_SOURCES})

target_include_directories(pw_dart_native
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
    SYSTEM PRIVATE ${PIPEWIRE_INCLUDE_DIRS}
)

target_link_libraries(pw_dart_native
    PRIVATE ${PIPEWIRE_LIBRARIES}
    PRIVATE glaze::glaze
)

target_compile_options(pw_dart_native
    PRIVATE ${PIPEWIRE_CFLAGS_OTHER}
    PRIVATE -Wall -Wextra
)

# --- Install ---
install(TARGETS pw_dart_native
    LIBRARY DESTINATION lib
)

# --- Tests ---
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../test/native
                     ${CMAKE_CURRENT_BINARY_DIR}/test_native)
endif()

