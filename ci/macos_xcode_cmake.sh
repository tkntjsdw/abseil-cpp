#!/bin/bash
#
# Copyright 2019 The Abseil Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euox pipefail

# Use Xcode 16.3
sudo xcode-select -s /Applications/Xcode_16.3.app/Contents/Developer

brew install cmake

export CMAKE_BUILD_PARALLEL_LEVEL=$(sysctl -n hw.ncpu)
export CTEST_PARALLEL_LEVEL=$(sysctl -n hw.ncpu)

if [[ -z ${ABSEIL_ROOT:-} ]]; then
  ABSEIL_ROOT="$(dirname ${0})/.."
fi
ABSEIL_ROOT=$(realpath ${ABSEIL_ROOT})

source "${ABSEIL_ROOT}/ci/cmake_common.sh"

if [[ -z ${ABSL_CMAKE_BUILD_TYPES:-} ]]; then
  ABSL_CMAKE_BUILD_TYPES="Debug"
fi

if [[ -z ${ABSL_CMAKE_BUILD_SHARED:-} ]]; then
  ABSL_CMAKE_BUILD_SHARED="OFF ON"
fi

if [[ -z ${ABSL_CMAKE_BUILD_MONOLITHIC_SHARED_LIBS:-} ]]; then
  ABSL_CMAKE_BUILD_MONOLITHIC_SHARED_LIBS="OFF ON"
fi

for compilation_mode in ${ABSL_CMAKE_BUILD_TYPES}; do
  for build_shared in ${ABSL_CMAKE_BUILD_SHARED}; do
    if [[ $build_shared == "OFF" ]]; then
      monolithic_shared_options="OFF"
    else
      monolithic_shared_options="$ABSL_CMAKE_BUILD_MONOLITHIC_SHARED_LIBS"
    fi

    for monolithic_shared in $monolithic_shared_options; do
      BUILD_DIR=$(mktemp -d ${compilation_mode}.XXXXXXXX)
      cd ${BUILD_DIR}

      # TODO(absl-team): Enable -Werror once all warnings are fixed.
      time cmake ${ABSEIL_ROOT} \
        -GXcode \
        -DBUILD_SHARED_LIBS=${build_shared} \
        -DABSL_BUILD_TESTING=ON \
        -DCMAKE_BUILD_TYPE=${compilation_mode} \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_MODULE_LINKER_FLAGS="-Wl,--no-undefined" \
        -DABSL_BUILD_MONOLITHIC_SHARED_LIBS=${monolithic_shared} \
        -DABSL_GOOGLETEST_DOWNLOAD_URL="${ABSL_GOOGLETEST_DOWNLOAD_URL}"
      time cmake --build .
      time TZDIR=${ABSEIL_ROOT}/absl/time/internal/cctz/testdata/zoneinfo \
        ctest -C ${compilation_mode} --output-on-failure
    done
  done
done
