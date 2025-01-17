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

# Exit immediately if sequence of one or more commands returns a non-zero status.
set -eo pipefail

SCRIPT_NAME=$(basename "${0}")
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1090
source "${SCRIPT_DIR}/common.sh" || exit 1

HELP=0
REPOSITORY=""
TAG="${APIGEE_HYBRID_VERSION}"

APIGEE_COMPONENTS=("apigee-mart-server" "apigee-synchronizer" "apigee-runtime" "apigee-hybrid-cassandra-client" "apigee-hybrid-cassandra" "apigee-cassandra-backup-utility" "apigee-udca" "apigee-connect-agent" "apigee-watcher" "apigee-operators" "apigee-installer" "apigee-redis" "apigee-diagnostics-collector" "apigee-diagnostics-runner")
THIRD_PARTY_COMPONENTS=("apigee-asm-istiod:1.12.9-asm.3" "apigee-asm-ingress:1.12.9-asm.3-distroless" "apigee-stackdriver-logging-agent:1.8.9" "apigee-prom-prometheus:v2.39.1" "apigee-stackdriver-prometheus-sidecar:0.9.0" "apigee-kube-rbac-proxy:v0.13.0" "apigee-envoy:v1.22.2" "apigee-prometheus-adapter:v0.10.0" "apigee-fluent-bit:1.9.9")

main() {
    # Validate prerequisite.
    validate_prerequisite

    # Parse arguments.
    parse_args "${@}"

    # Configure defaults.
    configure_defaults

    # Validate arguments.
    validate_args

    if [[ "${HELP}" -eq 1 ]]; then
        usage
        exit 0
    fi

    echo "${SCRIPT_NAME} will push images to ${REPOSITORY}"

    docker_exe "pull" "google" "${TAG}"
    docker_tag "google" "${REPOSITORY}" "${TAG}"
    docker_exe "push" "${REPOSITORY}" "${TAG}"
}

################################################################################
# Displays apigee pull push script usage details, when --help flag is specified.
################################################################################
usage() {
cat <<EOF
USAGE: ${SCRIPT_NAME} --repo <REPOSITORY>

FLAGS:

  --repo        <REPOSITORY>    Repository where you want to push the images.

  --project-id  <PROJECT_ID>    If the repository is not provided, Images will
                                be pushed to "us.gcr.io/<PROJECT_ID>".

NOTE: 1. Please make sure you have docker installed.
      2. If <PROJECT_ID> is not provided, and you have gcloud installed
         then it uses gcloud default configured <PROJECT_ID> to push images.

Example: ${SCRIPT_NAME} --repo foo.docker.com/hybrid-images
         ${SCRIPT_NAME} --project-id hybrid-setup
EOF
}

################################################################################
# Validate prerequisite.
################################################################################
validate_prerequisite() {
    # Check docker is installed and on the $PATH.
    if ! which docker > /dev/null 2>&1; then
        echo "docker is not installed or not on PATH."
        exit 0
    fi
}

################################################################################
# Parse arguments.
################################################################################
parse_args() {
    while [[ $# != 0 ]]; do
        case "${1}" in
        --help)
            HELP="1"
            shift 1
            ;;
        --repo)
            arg_required "${@}"
            REPOSITORY="${2}"
            shift 2
            ;;
        --project-id)
            arg_required "${@}"
            REPOSITORY="us.gcr.io/${2}"
            shift 2
            ;;
        *)
            fatal "Unknown option ${1}"
            ;;
        esac
    done
}

################################################################################
# Tries to configure the default values of unset variables.
################################################################################
configure_defaults() {
    # If repository and project-id is not provided.
    if [[ -z "${REPOSITORY}" ]]; then
      local PROJECT_ID
      # If gcloud is installed and on the $PATH.
      if ! which gcloud > /dev/null 2>&1; then
        PROJECT_ID="$(gcloud config get-value project)"
      fi
      # If gcloud configured project-id is not empty.
      if [[ -n "${PROJECT_ID}" ]]; then
        REPOSITORY="us.gcr.io/${PROJECT_ID}"
      fi
    fi
}

################################################################################
# Validate command line arguments.
################################################################################
validate_args() {
    if [[ "${HELP}" -eq 1 ]]; then
        return
    fi

    if [[ -z "${REPOSITORY}" ]]; then
        log_error "Repository and project-id both are not provided. Please check usage: \"${SCRIPT_NAME} --help\""
        exit 0
    fi

    if [[ -z "${TAG}" ]]; then
        echo "Tag is empty, it can not be empty."
        exit 0
    fi
}

################################################################################
# Docker helper functions.
################################################################################
docker_exe() {
    local action=$1
    local repo=$2
    local tag=$3

    for i in "${APIGEE_COMPONENTS[@]}"
    do
        docker "${action}" "${repo}/${i}:${tag}"
    done

    for i in "${THIRD_PARTY_COMPONENTS[@]}"
    do
        docker "${action}" "${repo}/${i}"
    done
}

docker_tag() {
    local source=$1
    local dest=$2
    local tag=$3

    for i in "${APIGEE_COMPONENTS[@]}"
    do
        docker tag "${source}/${i}:${tag}" "${dest}/${i}:${tag}"
    done

    for i in "${THIRD_PARTY_COMPONENTS[@]}"
    do
        docker tag "${source}/${i}" "${dest}/${i}"
    done
}

main "$@"