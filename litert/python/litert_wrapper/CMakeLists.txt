# Copyright 2025 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Python bindings for LiteRT - included from parent CMakeLists.txt
# This file should be included via add_subdirectory(python/litert_wrapper)
# Requires: PYTHON_INCLUDE_DIR and PYBIND11_INCLUDE_DIR to be set

if(NOT DEFINED PYTHON_INCLUDE_DIR)
  message(FATAL_ERROR "PYTHON_INCLUDE_DIR must be set")
endif()
if(NOT DEFINED PYBIND11_INCLUDE_DIR)
  message(FATAL_ERROR "PYBIND11_INCLUDE_DIR must be set")
endif()

# Get Python version from PYTHON_INCLUDE_DIR
# Expected format: /path/to/sysroot/usr/include/python3.13
string(REGEX MATCH "python([0-9]+)\\.([0-9]+)" _python_match "${PYTHON_INCLUDE_DIR}")
if(CMAKE_MATCH_COUNT EQUAL 2)
  set(PYTHON_VERSION_MAJOR "${CMAKE_MATCH_1}")
  set(PYTHON_VERSION_MINOR "${CMAKE_MATCH_2}")
else()
  # Fallback to 3.13 if regex doesn't match
  set(PYTHON_VERSION_MAJOR "3")
  set(PYTHON_VERSION_MINOR "13")
endif()

# Python extension suffix (e.g., cpython-313-aarch64-linux-gnu)
set(PYTHON_EXT_SUFFIX "cpython-${PYTHON_VERSION_MAJOR}${PYTHON_VERSION_MINOR}-${CMAKE_SYSTEM_PROCESSOR}-linux-gnu")

# Find Python library
if(DEFINED PYTHON_LIBRARY)
  set(PYTHON_LIB "${PYTHON_LIBRARY}")
else()
  message(FATAL_ERROR "PYTHON_LIBRARY must be set")
endif()

message(STATUS "Building Python wrappers for Python ${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}")
message(STATUS "Python extension suffix: ${PYTHON_EXT_SUFFIX}")

# ============================================================================
# Common utilities library
# ============================================================================

add_library(litert_wrapper_utils STATIC
  common/litert_wrapper_utils.cc
)
target_include_directories(litert_wrapper_utils
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${TENSORFLOW_SOURCE_DIR}>
    $<BUILD_INTERFACE:${TFLITE_SOURCE_DIR}>
    ${PYTHON_INCLUDE_DIR}
    ${PYBIND11_INCLUDE_DIR}
)

# ============================================================================
# Compiled Model Wrapper
# ============================================================================

# Core library
add_library(compiled_model_wrapper_lib STATIC
  compiled_model_wrapper/compiled_model_wrapper.cc
)
target_include_directories(compiled_model_wrapper_lib
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${TENSORFLOW_SOURCE_DIR}>
    $<BUILD_INTERFACE:${TFLITE_SOURCE_DIR}>
)
target_link_libraries(compiled_model_wrapper_lib
  PUBLIC
    litert_wrapper_utils
    litert_cc_api
    litert_runtime_c_api_shared_lib
    absl::flat_hash_map
    absl::span
    absl::strings
)

# pybind11 module - use standard add_library instead of pybind11_add_module
# for better cross-compilation support
add_library(_pywrap_litert_compiled_model_wrapper MODULE
  compiled_model_wrapper/compiled_model_wrapper_pybind11.cc
)
target_compile_options(_pywrap_litert_compiled_model_wrapper PRIVATE
  -fexceptions
)
target_include_directories(_pywrap_litert_compiled_model_wrapper
  PRIVATE
    ${PYTHON_INCLUDE_DIR}
    ${PYBIND11_INCLUDE_DIR}
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${TENSORFLOW_SOURCE_DIR}>
    $<BUILD_INTERFACE:${TFLITE_SOURCE_DIR}>
)
target_link_libraries(_pywrap_litert_compiled_model_wrapper
  PRIVATE
    compiled_model_wrapper_lib
    litert_cc_api
    litert_runtime_c_api_shared_lib
    ${PYTHON_LIB}
    absl::flat_hash_map
    absl::string_view
)

# Set output name with Python extension suffix
set_target_properties(_pywrap_litert_compiled_model_wrapper PROPERTIES
  OUTPUT_NAME "_pywrap_litert_compiled_model_wrapper.${PYTHON_EXT_SUFFIX}"
  PREFIX ""
  SUFFIX ".so"
)

# Set RPATH for finding libLiteRtRuntimeCApi.so
set_target_properties(_pywrap_litert_compiled_model_wrapper PROPERTIES
  INSTALL_RPATH "$ORIGIN:$ORIGIN/../lib"
  BUILD_WITH_INSTALL_RPATH TRUE
)

# ============================================================================
# Tensor Buffer Wrapper
# ============================================================================

# Core library
add_library(tensor_buffer_wrapper_lib STATIC
  tensor_buffer_wrapper/tensor_buffer_wrapper.cc
)
target_include_directories(tensor_buffer_wrapper_lib
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${TENSORFLOW_SOURCE_DIR}>
    $<BUILD_INTERFACE:${TFLITE_SOURCE_DIR}>
)
target_link_libraries(tensor_buffer_wrapper_lib
  PUBLIC
    litert_wrapper_utils
    litert_cc_api
    litert_runtime_c_api_shared_lib
    absl::span
)

# pybind11 module
add_library(_pywrap_litert_tensor_buffer_wrapper MODULE
  tensor_buffer_wrapper/tensor_buffer_wrapper_pybind11.cc
)
target_compile_options(_pywrap_litert_tensor_buffer_wrapper PRIVATE
  -fexceptions
)
target_include_directories(_pywrap_litert_tensor_buffer_wrapper
  PRIVATE
    ${PYTHON_INCLUDE_DIR}
    ${PYBIND11_INCLUDE_DIR}
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${TENSORFLOW_SOURCE_DIR}>
    $<BUILD_INTERFACE:${TFLITE_SOURCE_DIR}>
)
target_link_libraries(_pywrap_litert_tensor_buffer_wrapper
  PRIVATE
    tensor_buffer_wrapper_lib
    litert_cc_api
    litert_runtime_c_api_shared_lib
    ${PYTHON_LIB}
    absl::flat_hash_map
    absl::string_view
)

# Set output name with Python extension suffix
set_target_properties(_pywrap_litert_tensor_buffer_wrapper PROPERTIES
  OUTPUT_NAME "_pywrap_litert_tensor_buffer_wrapper.${PYTHON_EXT_SUFFIX}"
  PREFIX ""
  SUFFIX ".so"
)

# Set RPATH for finding libLiteRtRuntimeCApi.so
set_target_properties(_pywrap_litert_tensor_buffer_wrapper PROPERTIES
  INSTALL_RPATH "$ORIGIN:$ORIGIN/../lib"
  BUILD_WITH_INSTALL_RPATH TRUE
)

# ============================================================================
# Installation
# ============================================================================

install(TARGETS
  _pywrap_litert_compiled_model_wrapper
  _pywrap_litert_tensor_buffer_wrapper
  DESTINATION .
)
