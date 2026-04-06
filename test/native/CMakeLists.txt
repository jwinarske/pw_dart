cmake_minimum_required(VERSION 3.22)

# --- GoogleTest ---
include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG        v1.15.2
  GIT_SHALLOW    TRUE
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

include(GoogleTest)

# --- Common test settings ---
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include the main source directory for headers
set(PW_DART_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../src)

# --- command_queue_test ---
add_executable(command_queue_test command_queue_test.cpp)
target_include_directories(command_queue_test PRIVATE ${PW_DART_SRC_DIR})
target_link_libraries(command_queue_test PRIVATE GTest::gtest_main)
gtest_discover_tests(command_queue_test)

# --- event_serializer_test ---
add_executable(event_serializer_test event_serializer_test.cpp)
target_include_directories(event_serializer_test PRIVATE ${PW_DART_SRC_DIR})
target_link_libraries(event_serializer_test
    PRIVATE GTest::gtest_main
    PRIVATE glaze::glaze
)
gtest_discover_tests(event_serializer_test)

# --- param_handler_test ---
add_executable(param_handler_test param_handler_test.cpp)
target_include_directories(param_handler_test PRIVATE ${PW_DART_SRC_DIR})
target_link_libraries(param_handler_test
    PRIVATE GTest::gtest_main
    PRIVATE glaze::glaze
)
gtest_discover_tests(param_handler_test)

# --- link_manager_test ---
add_executable(link_manager_test link_manager_test.cpp)
target_include_directories(link_manager_test PRIVATE ${PW_DART_SRC_DIR})
target_link_libraries(link_manager_test
    PRIVATE GTest::gtest_main
    PRIVATE glaze::glaze
)
gtest_discover_tests(link_manager_test)

