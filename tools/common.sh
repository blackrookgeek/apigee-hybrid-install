#!/usr/bin/env bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APIGEE_HYBRID_VERSION="1.8.3"   # Apigee hybrid version that will be installed.
GCP_NON_PROD_SERVICE_ACCOUNT_NAME="apigee-non-prod"   # Name of the service account that will be created

################################################################################
# Functions for logging error and info.
################################################################################

log_error(){
    printf "\\n[ERROR]: %b\\n\\n" "$*"
    exit 1
}

log_info(){
    printf "\\n[INFO]: %b\\n" "$*"
}

################################################################################
# Checks for the existence of a second argument and exit if it does not exist.
################################################################################
arg_required() {
    if [[ ! "${2:-}" || "${2:0:1}" = '-' ]]; then
        fatal "Option ${1} requires an argument."
    fi
}