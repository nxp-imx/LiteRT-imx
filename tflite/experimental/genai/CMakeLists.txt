#
# Copyright 2021 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


populate_source_vars("${TFLITE_SOURCE_DIR}/experimental/genai"
  LITERT_GENAI_OPS_SRCS
  FILTER "_test\\.cc$"
)

add_library(pywrap_genai_ops SHARED EXCLUDE_FROM_ALL

# To remove "lib" prefix.
set_target_properties(pywrap_genai_ops PROPERTIES PREFIX "")

include_directories(pywrap_genai_ops
  PUBLIC
  ${TENSORFLOW_SOURCE_DIR}
)

