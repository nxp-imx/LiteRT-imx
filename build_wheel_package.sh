#!/bin/bash
#
# build_wheel_package.sh - Build LiteRT Python wheel package
#
# Usage:
#   ./build_wheel_package.sh [BUILD_DIR] [OPTIONS]
#
#   BUILD_DIR defaults to build_python_arm64
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERT_ROOT="${SCRIPT_DIR}"

# Defaults
BUILD_DIR=""
SOURCE_DIR="${LITERT_ROOT}"
VERSION=""
PLAT_NAME="linux_aarch64"
PYTHON="python3"

usage() {
    cat << EOF
Usage: $(basename "$0") [BUILD_DIR] [OPTIONS]

Arguments:
  BUILD_DIR    Build root directory (default: build_python_arm64)

Options:
  -s DIR    Source root directory (default: current)
  -v VER    Package version (default: from git tag)
  -p NAME   Platform name (default: linux_aarch64)
  -P CMD    Python command (default: python3)
  -h        Show this help

Example:
  $(basename "$0")                              # Use default build dir
  $(basename "$0") /path/to/build               # Specify build dir
  $(basename "$0") -v 2.1.0 -P python3.11       # Custom version and python
EOF
    exit 0
}

# Parse positional argument first
[ -n "$1" ] && [[ ! "$1" =~ ^- ]] && BUILD_DIR="$1" && shift

while getopts "s:v:p:P:h" opt; do
    case $opt in
        s) SOURCE_DIR="$OPTARG" ;;
        v) VERSION="$OPTARG" ;;
        p) PLAT_NAME="$OPTARG" ;;
        P) PYTHON="$OPTARG" ;;
        h) usage ;;
        ?) exit 1 ;;
    esac
done

# Set default build dir
[ -z "${BUILD_DIR}" ] && BUILD_DIR="${LITERT_ROOT}/build_python_arm64"

# Derived paths
TFLITE_BUILD_DIR="${BUILD_DIR}/tflite_build"
LIB_BUILD_DIR="${BUILD_DIR}/"
OUTPUT_DIR="${BUILD_DIR}/install"
WHEEL_BUILD_DIR="${BUILD_DIR}/wheel"

# Verify libLiteRt.so exists
if [ ! -f "${LIB_BUILD_DIR}/c/libLiteRt.so" ] && [ ! -f "${OUTPUT_DIR}/lib/libLiteRt.so" ]; then
    echo "Error: libLiteRt.so not found in ${LIB_BUILD_DIR}/c or ${OUTPUT_DIR}/lib"
    exit 1
fi

# Get version
[ -z "${VERSION}" ] && VERSION="$(git -C "${LITERT_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo v2.1.0)"
VERSION="${VERSION#v}+arm64"

echo "Building ai_edge_litert ${VERSION}"
echo "  Build: ${BUILD_DIR}"

# Prepare package directory
rm -rf "${WHEEL_BUILD_DIR}"
PKG_DIR="${WHEEL_BUILD_DIR}/ai_edge_litert/ai_edge_litert"
mkdir -p "${PKG_DIR}/aot/core" "${PKG_DIR}/aot/vendors" "${PKG_DIR}/aot/ai_pack"
mkdir -p "${PKG_DIR}/tools" "${PKG_DIR}/vendors" "${PKG_DIR}/tflite/tflite" "${PKG_DIR}/internal"

# Copy Python files
cp "${SOURCE_DIR}"/litert/python/*.py "${PKG_DIR}/" 2>/dev/null || true
[ -f "${SOURCE_DIR}/tflite/python/interpreter.py" ] && \
    sed 's/tflite_runtime/ai_edge_litert/g' "${SOURCE_DIR}/tflite/python/interpreter.py" > "${PKG_DIR}/interpreter.py"
[ -f "${SOURCE_DIR}/tflite/python/metrics/metrics_portable.py" ] && \
    sed 's/tflite_runtime/ai_edge_litert/g' "${SOURCE_DIR}/tflite/python/metrics/metrics_portable.py" > "${PKG_DIR}/metrics_portable.py"
cp "${SOURCE_DIR}/tflite/python/metrics/metrics_interface.py" "${PKG_DIR}/" 2>/dev/null || true

# Generate tflite schema
command -v flatc &>/dev/null && [ -f "${SOURCE_DIR}/tflite/compiler/mlir/lite/schema/schema.fbs" ] && \
    flatc --python -o "${PKG_DIR}/tflite/tflite" "${SOURCE_DIR}/tflite/compiler/mlir/lite/schema/schema.fbs" 2>/dev/null
[ -d "${PKG_DIR}/tflite/tflite" ] && echo '"""TFLite schema"""' > "${PKG_DIR}/tflite/__init__.py"

# internal/
cp "${SOURCE_DIR}/litert/python/internal"/*.py "${PKG_DIR}/internal/" 2>/dev/null || true

# litert_wrapper
for d in compiled_model_wrapper tensor_buffer_wrapper common; do
    cp "${SOURCE_DIR}/litert/python/litert_wrapper/${d}"/*.py "${PKG_DIR}/" 2>/dev/null || true
done

# aot/
cp "${SOURCE_DIR}/litert/python/aot/"*.py "${PKG_DIR}/aot/" 2>/dev/null || true
cp "${SOURCE_DIR}/litert/python/aot/core/"*.py "${PKG_DIR}/aot/core/" 2>/dev/null || true
cp "${SOURCE_DIR}/litert/python/aot/vendors/"*.py "${PKG_DIR}/aot/vendors/" 2>/dev/null || true

# Fix aot imports
find "${PKG_DIR}/aot" -name "*.py" -exec sed -i \
    -e 's/from litert\.python\.aot\.vendors\./from ai_edge_litert.aot.vendors./g' \
    -e 's/from litert\.python\.aot\.core/from ai_edge_litert.aot.core/g' \
    -e 's/from litert\.python\.aot/from ai_edge_litert.aot/g' \
    -e 's/from litert\.python/from ai_edge_litert/g' {} \;
[ -f "${PKG_DIR}/aot/core/common.py" ] && sed -i \
    -e 's/_WORKSPACE_PREFIX = "litert"/_WORKSPACE_PREFIX = "ai_edge_litert"/' \
    -e 's/_PYTHON_ROOT = "python\/aot"/_PYTHON_ROOT = "aot"/' "${PKG_DIR}/aot/core/common.py"

# tools/
cp "${SOURCE_DIR}/litert/python/tools"/*.py "${PKG_DIR}/tools/" 2>/dev/null || true
[ -f "${LIB_BUILD_DIR}/tools/apply_plugin_main" ] && \
    cp "${LIB_BUILD_DIR}/tools/apply_plugin_main" "${PKG_DIR}/tools/" && chmod +x "${PKG_DIR}/tools/apply_plugin_main"

# proto files
command -v protoc &>/dev/null && {
    PROTO_TMP="${BUILD_DIR}/proto_generated"
    mkdir -p "${PROTO_TMP}"
    protoc --python_out="${PROTO_TMP}" --proto_path="${SOURCE_DIR}" \
        "${SOURCE_DIR}/tflite/profiling/proto"/*.proto 2>/dev/null || true
    cp "${PROTO_TMP}/tflite/profiling/proto/"*.py "${PKG_DIR}/" 2>/dev/null || true
}

# Copy .so files
[ -f "${LIB_BUILD_DIR}/c/libLiteRt.so" ] && cp "${LIB_BUILD_DIR}/c/libLiteRt.so" "${PKG_DIR}/"
[ -f "${OUTPUT_DIR}/lib/libLiteRt.so" ] && cp "${OUTPUT_DIR}/lib/libLiteRt.so" "${PKG_DIR}/"
find "${LIB_BUILD_DIR}" "${OUTPUT_DIR}" -name "_pywrap_*.so" -exec cp {} "${PKG_DIR}/" \; 2>/dev/null || true

# TFLite wrappers
[ -f "${TFLITE_BUILD_DIR}/_pywrap_tensorflow_interpreter_wrapper.so" ] && \
    cp "${TFLITE_BUILD_DIR}/_pywrap_tensorflow_interpreter_wrapper.so" "${PKG_DIR}/_pywrap_litert_interpreter_wrapper.so"
for so in lib_pywrap_analyzer_wrapper.so lib_pywrap_modify_model_interface.so \
          libformat_converter_wrapper_pybind11.so libpywrap_genai_ops.so; do
    [ -f "${TFLITE_BUILD_DIR}/${so}" ] && cp "${TFLITE_BUILD_DIR}/${so}" "${PKG_DIR}/"
done

# Create __init__.py files
echo '"""ai_edge_litert - LiteRT for on-device AI"""' > "${PKG_DIR}/__init__.py"
touch "${PKG_DIR}/aot/__init__.py" "${PKG_DIR}/aot/core/__init__.py" "${PKG_DIR}/aot/vendors/__init__.py"
touch "${PKG_DIR}/aot/ai_pack/__init__.py" "${PKG_DIR}/tools/__init__.py" "${PKG_DIR}/vendors/__init__.py"
touch "${PKG_DIR}/internal/__init__.py"

# setup.py
cat > "${WHEEL_BUILD_DIR}/ai_edge_litert/setup.py" << EOF
from setuptools import setup, find_packages
setup(
    name="ai_edge_litert",
    version="${VERSION}",
    packages=find_packages(exclude=("*.test",)),
    package_data={"": ["*.so", "*.py"]},
    include_package_data=True,
    python_requires=">=3.8",
    install_requires=["numpy>=1.23.2", "flatbuffers"],
)
EOF

# pyproject.toml
cat > "${WHEEL_BUILD_DIR}/ai_edge_litert/pyproject.toml" << EOF
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"
[project]
name = "ai_edge_litert"
version = "${VERSION}"
requires-python = ">=3.8"
dependencies = ["numpy>=1.23.2", "flatbuffers"]
[tool.setuptools]
include-package-data = true
EOF

# Build wheel
cd "${WHEEL_BUILD_DIR}/ai_edge_litert"
${PYTHON} setup.py bdist_wheel --plat-name "${PLAT_NAME}"

# Copy to output
WHEEL_FILE=$(find ./dist -name "*.whl" | head -1)
[ -n "${WHEEL_FILE}" ] && {
    mkdir -p "${OUTPUT_DIR}"
    cp "${WHEEL_FILE}" "${OUTPUT_DIR}/"
    echo ""
    echo "Done: ${OUTPUT_DIR}/${WHEEL_FILE##*/}"
} || { echo "Error: Wheel not created"; exit 1; }
