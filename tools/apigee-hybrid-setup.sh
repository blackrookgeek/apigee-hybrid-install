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

set -eo pipefail

if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
    cat <<EOF >&2
WARNING: bash ${BASH_VERSION} does not support several modern safety features.
This script was written with bash v4+ in mind, and was only
tested with bash v5+. This script may not perform correctly in
this environment.
EOF
    sleep 1
else
    set -u
fi

################################################################################
#                           User modifiable variables
################################################################################

APIGEE_API_ENDPOINT="https://apigee.googleapis.com" # API endpoint to be used to Apigee API calls

ORGANIZATION_NAME="${ORGANIZATION_NAME:-""}"                   # --org
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-""}"                     # --env
ENVIRONMENT_GROUP_NAME="${ENVIRONMENT_GROUP_NAME:-""}"         # --envgroup
ENVIRONMENT_GROUP_HOSTNAME="${ENVIRONMENT_GROUP_HOSTNAME:-""}" # --ingress-domain
APIGEE_NAMESPACE="${APIGEE_NAMESPACE:-"apigee"}"               # --namespace, The kubernetes namespace name where Apigee components will be created
CLUSTER_NAME="${CLUSTER_NAME:-""}"                             # --cluster-name
CLUSTER_REGION="${CLUSTER_REGION:-""}"                         # --cluster-region
GCP_PROJECT_ID="${GCP_PROJECT_ID:-""}"                         # --gcp-project-id
# X~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~X END X~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~X


# Commands
ADD_CLUSTER="0"
ADD_ENVIRONGROUP="0"
ADD_ENVIRONMENT="0"
CHECK_ALL="0"
PRINT_YAML_ALL="0"
CREATE_DEMO="0"
ENABLE_ADD_ON="0"
ADD_ON=""


VERBOSE="0" # --verbose
DIAGNOSTIC="0" # --diagnostic

HAS_TS="0"
AGCLOUD=""
ASED=""

SCRIPT_NAME="${0##*/}"
SCRIPT_PATH=$(realpath -s "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
INSTANCE_DIR=""

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/common.sh" || exit 1

TEMPLATES_DIR="${ROOT_DIR}/templates"
NONPROD_INSTANCE_TEMP="${TEMPLATES_DIR}/non-prod-instance"
NONPROD_ENVGROUP_TEMP="${TEMPLATES_DIR}/non-prod-envgroup"
NONPROD_ENVIRONMENT_TEMP="${TEMPLATES_DIR}/non-prod-environment"
ADD_ONS_DIR="${TEMPLATES_DIR}/add-ons"

################################################################################
# `main` is the ENTRYPOINT for the shell script.
################################################################################
main() {
    init
    parse_args "${@}"
    check_prerequisites
    resolve_flags
    validate_args
    configure_vars


    if [[ "${DIAGNOSTIC}" == "1" ]]; then
        print_diagnostics
    fi


    if [[ "${ADD_CLUSTER}" == "1" ]]; then
        add_cluster

    elif [[ "${ADD_ENVIRONGROUP}" == "1" ]]; then
        add_environ_group

    elif [[ "${ADD_ENVIRONMENT}" == "1" ]]; then
        add_environment

    elif [[ "${CHECK_ALL}" == "1" ]]; then
        check_all

    elif [[ "${PRINT_YAML_ALL}" == "1" ]]; then
        print_yaml_all

    elif [[ "${CREATE_DEMO}" == "1" ]]; then
        create_demo

    elif [[ "${ENABLE_ADD_ON}" == "1" ]]; then
        enable_add_on
    fi

    banner_info "SUCCESS"
}


################################################################################
# prints internal variable information
################################################################################
print_diagnostics() {

    info ""
    info "Provided and calculated values..."
    info "ORGANIZATION_NAME='${ORGANIZATION_NAME}'"
    info "ENVIRONMENT_GROUP_NAME='${ENVIRONMENT_GROUP_NAME}'"
    info "ENVIRONMENT_GROUP_HOSTNAME='${ENVIRONMENT_GROUP_HOSTNAME}'"
    info "ENVIRONMENT_NAME='${ENVIRONMENT_NAME}'"
    info "APIGEE_NAMESPACE='${APIGEE_NAMESPACE}'"
    info "CLUSTER_NAME='${CLUSTER_NAME}'"
    info "CLUSTER_REGION='${CLUSTER_REGION}'"
    info "GCP_PROJECT_ID='${GCP_PROJECT_ID}'"
    info "INSTANCE_DIR='${INSTANCE_DIR}'"
    info ""
    info "Commands..."
    info "ADD_CLUSTER='${ADD_CLUSTER}'"
    info "ADD_ENVIRONGROUP='${ADD_ENVIRONGROUP}'"
    info "ADD_ENVIRONMENT='${ADD_ENVIRONMENT}'"
    info "CHECK_ALL='${CHECK_ALL}'"
    info "PRINT_YAML_ALL='${PRINT_YAML_ALL}'"
    info "CREATE_DEMO='${CREATE_DEMO}'"
    info "ENABLE_ADD_ON='${ENABLE_ADD_ON}'"
    info "ADD_ON='${ADD_ON}'"
    info ""
    info "Flags..."
    info "VERBOSE='${VERBOSE}'"
    info "DIAGNOSTIC='${DIAGNOSTIC}'"
    info ""
    info "Script locations..."
    info "SCRIPT_NAME='${SCRIPT_NAME}'"
    info "SCRIPT_PATH='${SCRIPT_PATH}'"
    info "SCRIPT_DIR='${SCRIPT_DIR}'"
    info "ROOT_DIR='${ROOT_DIR}'"
    info "TEMPLATES_DIR='${TEMPLATES_DIR}'"
    info "NONPROD_INSTANCE_TEMP='${NONPROD_INSTANCE_TEMP}'"
    info "NONPROD_ENVGROUP_TEMP='${NONPROD_ENVGROUP_TEMP}'"
    info "NONPROD_ENVIRONMENT_TEMP='${NONPROD_ENVIRONMENT_TEMP}'"
    info "ADD_ONS_DIR='${ADD_ONS_DIR}'"
}



################################################################################
# add_cluster
################################################################################
add_cluster() {

    banner_info "Adding Cluster: ${CLUSTER_NAME}-${CLUSTER_REGION}"

    info "Copying cluster template into /overlays..."
    run cp -R "${NONPROD_INSTANCE_TEMP}" "${INSTANCE_DIR}"

    fill_values_in_yamls

}



################################################################################
# add_environ_group
################################################################################
add_environ_group() {

    banner_info "Adding Environment Group: ${ENVIRONMENT_GROUP_NAME} to ${CLUSTER_NAME}-${CLUSTER_REGION}"

    if [[ -d "${INSTANCE_DIR}/route-config/" ]]; then
        info "Adding ${ENVIRONMENT_GROUP_NAME} to kustomization.yaml"
        echo "- ${ENVIRONMENT_GROUP_NAME}" >> "${INSTANCE_DIR}/route-config/kustomization.yaml"

        info "Copying Environment Group patch folder"
        run cp -R "${NONPROD_ENVGROUP_TEMP}" "${INSTANCE_DIR}/route-config/${ENVIRONMENT_GROUP_NAME}"

        fill_values_in_yamls

        info ""
        info "NOTE: default configuration uses a cert-manager provided certificate for ingress."
        info "Update kustomization.yaml and customer-provided-ingress-certificate.yaml to use"
        info "a provided certificate"

    else
        error "Searching for Instance folder:"
        error "  ${INSTANCE_DIR}/route-config/"
        error ""
        fatal "Error: Instance Folder not found. Ensure command: [add cluster] has already been executed for specified cluster."
    fi


}



################################################################################
# aadd_environmentoeu
################################################################################
add_environment() {

    banner_info "Adding Environment: ${ENVIRONMENT_NAME} to ${CLUSTER_NAME}-${CLUSTER_REGION}"

    if [[ -d "${INSTANCE_DIR}/environments/" ]]; then
        info "Adding ${ENVIRONMENT_NAME} to kustomization.yaml"
        echo "- ${ENVIRONMENT_NAME}" >> "${INSTANCE_DIR}/environments/kustomization.yaml"

        info "Copying Environment patch folder"
        run cp -R "${NONPROD_ENVIRONMENT_TEMP}" "${INSTANCE_DIR}/environments/${ENVIRONMENT_NAME}"

        fill_values_in_yamls

    else
        error "Searching for Instance folder:"
        error "  ${INSTANCE_DIR}/environments/"
        error ""
        fatal "Error: Instance Folder not found. Ensure command: [add cluster] has already been executed for specified cluster."
    fi

}



################################################################################
# check_all
################################################################################
check_all() {

    banner_info "Validating a base configuration has been completed."

    local VALIDATION_FAILED=0

    if [[ $(ls -1 "${ROOT_DIR}/overlays/instances" | wc -l) == 0 ]]; then
        VALIDATION_FAILED=1
        error "No Clusters found. Run [add cluster] to add a cluster. Then add an Environment and Environment Group."
    else

        for f in $(find ${ROOT_DIR}/overlays/instances/ -maxdepth 1 -type d -not -path ${ROOT_DIR}/overlays/instances/ )
        do
            if [[ $(ls -1 "${f}/route-config" | wc -l) == 1 ]]; then
                VALIDATION_FAILED=1
                error "No Environment Groups found in cluster ${f}. Run [add environment-group] to add an Environment Group to the cluster."
            fi

            if [[ $(ls -1 "${f}/environments" | wc -l) == 1 ]]; then
                VALIDATION_FAILED=1
                error "No Environments found in cluster ${f}. Run [add environment] to add an Environment to the cluster."
            fi
        done

    fi

    if [[ $(grep -rnl ${ROOT_DIR}/bases/ -e '${' | wc -l) > 0 ]]; then
        VALIDATION_FAILED=1
        error "The following files appear to have manifest variables that have been unresolved:"
        run grep -rnl ${ROOT_DIR}/bases/ -e '${'
    fi

    if [[ $(grep -rnl ${ROOT_DIR}/overlays/ -e '${' | wc -l) > 0 ]]; then
        VALIDATION_FAILED=1
        error "The following files appear to have manifest variables that have been unresolved:"
        run grep -rnl ${ROOT_DIR}/overlays/ -e '${'
    fi


    if [[ "${VALIDATION_FAILED}" == 1 ]]; then
        error ""
        fatal "One or more validations failed. Exiting."
    fi

}



################################################################################
# print_yaml_all
################################################################################
print_yaml_all() {

    banner_info "Printing all Organization manifests."
    info "DOES NOT INCLUDE SERVICE ACCOUNTS"
    info "DOES NOT INCLUDE SECRETS"
    info ""

    info "Printing Initialization..."
    run kubectl kustomize "${ROOT_DIR}/overlays/initialization"

    info "Printing controllers..."
    run kubectl kustomize "${ROOT_DIR}/overlays/controllers"

    info "Locations of Org Secret manifests..."
    run find "${ROOT_DIR}/bases/" -name *secrets.yaml

    for f in $(find ${ROOT_DIR}/overlays/instances/ -maxdepth 1 -type d -not -path ${ROOT_DIR}/overlays/instances/ )
    do

        info "Printing information for Cluster: ${f}"

        info "Locations of Instance Secret manifests..."
        run find "${f}" -name *secrets.yaml

        info "Printing Ingress certificates..."
        # Create the ingress certificate secrets.
        run find "${f}" -name *ingress-certificate.yaml | xargs -n 1 cat

        info "Printing all remaining Apigee resources..."
        # Create the remainder of the resources.
        run kubectl kustomize "${f}" --reorder none

    done


}



################################################################################
# create_demo
################################################################################
create_demo() {

    banner_info "Creating Demo manifests."
    info "NOTE: This is not fully tested right now"

    # All Demo Attributes are pulled from defaults or from the Apigee Organization provided

    info "Adding Demo Cluster: ${cluster-name}- ${cluster-region}"
    add_cluster

    info "Adding Environment Group: ${ENVIRONMENT_GROUP_NAME} @ ${ENVIRONMENT_GROUP_HOSTNAME}"
    add_environ_group

    info "Adding Environment: ${ENVIRONMENT_NAME}"
    add_environment
    
    info "Creating and Adding an all-in-one Service Account"
    create_demo_service_account

}




################################################################################
# enable add on
################################################################################
enable_add_on() {

    banner_info "Enabling Add-on: ${ADD_ON}."
    info "Note: this feature is not fully tested yet"
    warn "Many of the Add-on Features require custom information to be filled in."
    warn "Be careful to check all added files for variables and consistancy."
    warn "The added files are typically in a folder with the same name as the Add-on."

    local SELECTED_ADD_ONS_DIR="${ADD_ONS_DIR}/${ADD_ON}"

    # copy in the top of the overlays
    if [ -d "${SELECTED_ADD_ONS_DIR}/add-on-overlays/" ]; then
        run cp -R "${SELECTED_ADD_ONS_DIR}/add-on-overlays/"* "${ROOT_DIR}/overlays"
    fi

    # for each instance
    for instance in $(find ${ROOT_DIR}/overlays/instances/ -maxdepth 1 -type d -not -path ${ROOT_DIR}/overlays/instances/ )
    do

        if [ -d "${SELECTED_ADD_ONS_DIR}/add-on-instance/" ]; then
            run cp -R "${SELECTED_ADD_ONS_DIR}/add-on-instance/"* ${instance}
        fi

        # for each group
        for group in $(find ${instance}/route-config/ -maxdepth 1 -type d -not -path ${instance}/route-config/ )
        do
            if [ -d "${SELECTED_ADD_ONS_DIR}/add-on-envgroup/" ]; then
                run cp -R "${SELECTED_ADD_ONS_DIR}/add-on-envgroup/"* ${group}
            fi
        done

        # for each environment
        for environment in $(find ${instance}/environments/ -maxdepth 1 -type d -not -path ${instance}/environments/ )
        do
            if [ -d "${SELECTED_ADD_ONS_DIR}/add-on-environment/" ]; then
                run cp -R "${SELECTED_ADD_ONS_DIR}/add-on-environment/"* ${environment}
            fi
        done

    done


    # Merge all kustomization.yaml.append files to their parent
        # a = info to be appended
        # f = kustomize file to append to
    for a in $(find ${ROOT_DIR}/overlays/ -type f -name *.append )
    do
        local f=${a:0:-7} #chop off the .append
        run cat ${f} ${a} >> ${f}.tmp
        run mv ${f}.tmp ${f}
        run rm ${a}
    done

    # attempt to fill values.
    # NOTE: THIS IS NOT PERFECT. It will need some work to handle multi-instance, env, env-group configs
    fill_values_in_yamls


}




################################################################################
# Replace appropriate values like org, env, envgroup name in the yamls.
################################################################################
fill_values_in_yamls() {
    banner_info "Filling values in YAMLs..."

    # export values into execution space
    export CASSANDRA_DC_NAME="${CLUSTER_NAME}-${CLUSTER_REGION}"
    export ORGANIZATION_NAME_UPPER="$(echo "${ORGANIZATION_NAME}" | tr 'a-z' 'A-Z')"
    export ENVIRONMENT_NAME_UPPER="$(echo "${ENVIRONMENT_NAME}" | tr 'a-z' 'A-Z')"
    export APIGEE_NAMESPACE ENVIRONMENT_NAME ENVIRONMENT_GROUP_NAME ENVIRONMENT_GROUP_HOSTNAME CLUSTER_NAME CLUSTER_REGION GCP_SERVICE_ACCOUNT_NAME GCP_PROJECT_ID ORGANIZATION_NAME

    # search each file for variables to be replaced
    for f in $(find ${ROOT_DIR}/bases/ -type f)
    do
        sed -i -E -e "s/[:].*kpt-set//" $f
        sed -i -E -e "s/- .*kpt-set: /- /" $f
        envsubst < "$f" > ${f}.tmp
        mv ${f}.tmp ${f}
    done
    for f in $(find ${ROOT_DIR}/overlays/ -type f)
    do
        sed -i -E -e "s/[:].*kpt-set//" $f
        sed -i -E -e "s/- .*kpt-set: /- /" $f
        envsubst < "$f" > ${f}.tmp
        mv ${f}.tmp ${f}
    done

}

################################################################################
# For the demo configuration, generate an all-in-one, non-prod, service account
################################################################################
create_demo_service_account() {
    # Unset the PROJECT_ID variable because the `create-service-account` script
    # errors out if both the flag `--project-id` and environment variable are
    # set.
    unset PROJECT_ID

    banner_info "Configuring GCP non-prod service account..."

    local SERVICE_ACCOUNT_OUTPUT_DIR="${ROOT_DIR}/service-accounts"


    if [ ! -f "${SERVICE_ACCOUNT_OUTPUT_DIR}/${ORGANIZATION_NAME}-${GCP_NON_PROD_SERVICE_ACCOUNT_NAME}.json" ]; then
        info "Service account keys NOT FOUND. Attempting to create a new service account and downloading its keys."
        run "${SCRIPT_DIR}/create-service-account.sh" \
            --project-id "${ORGANIZATION_NAME}" \
            --env "non-prod" \
            --name "${GCP_NON_PROD_SERVICE_ACCOUNT_NAME}" \
            --dir "${SERVICE_ACCOUNT_OUTPUT_DIR}" <<<"y"
    else
        info "Service account keys FOUND at '${SERVICE_ACCOUNT_OUTPUT_DIR}/${ORGANIZATION_NAME}-${GCP_NON_PROD_SERVICE_ACCOUNT_NAME}.json'."
        info "Skipping recreation of service account and keys."
    fi

    info "Checking if the key is valid..."
    GOOGLE_APPLICATION_CREDENTIALS="${SERVICE_ACCOUNT_OUTPUT_DIR}/${ORGANIZATION_NAME}-${GCP_NON_PROD_SERVICE_ACCOUNT_NAME}.json" \
        gcloud auth application-default print-access-token >/dev/null

    info "Calling setSyncAuthoriation API..."
    local JSON_DATA
    JSON_DATA="$(
        curl --fail --show-error --silent "${APIGEE_API_ENDPOINT}/v1/organizations/${ORGANIZATION_NAME}:getSyncAuthorization" \
            -K <(auth_header) |
            jq '.identities += ["serviceAccount:'"${GCP_NON_PROD_SERVICE_ACCOUNT_NAME}"'@'"${ORGANIZATION_NAME}"'.iam.gserviceaccount.com"] | .identities'
    )"
    run curl --fail --show-error --silent "${APIGEE_API_ENDPOINT}/v1/organizations/${ORGANIZATION_NAME}:setSyncAuthorization" \
        -X POST -H "Content-Type:application/json" \
        -d '{"identities":'"${JSON_DATA}"'}' \
        -K <(auth_header)

}




################################################################################
#   _   _      _                   _____                 _   _
#  | | | | ___| |_ __   ___ _ __  |  ___|   _ _ __   ___| |_(_) ___  _ __  ___
#  | |_| |/ _ \ | '_ \ / _ \ '__| | |_ | | | | '_ \ / __| __| |/ _ \| '_ \/ __|
#  |  _  |  __/ | |_) |  __/ |    |  _|| |_| | | | | (__| |_| | (_) | | | \__ \
#  |_| |_|\___|_| .__/ \___|_|    |_|   \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#               |_|
################################################################################

init() {
    if hash ts 2>/dev/null; then
        HAS_TS="1"
    fi
    readonly HAS_TS

    AGCLOUD="$(which gcloud)"
    ASED="$(which sed)"
}

################################################################################
# Check if all the commands that we depend on are installed.
################################################################################
check_prerequisites() {
    local NOTFOUND
    NOTFOUND="0"

    if [[ "${CREATE_DEMO}" == "1" ]]; then
        info "Checking prerequisites for the Demo Configuration commands..."
        while read -r dependency; do
            if ! command -v "${dependency}" &>/dev/null; then
                NOTFOUND="1"
                warn "Command '${dependency}' not found."
            fi
        done <<EOF
curl
jq
envsubst
$AGCLOUD
$ASED
EOF

    else # curl and gcloud are not required for standard configuration operations
        info "Checking prerequisite commands..."
        while read -r dependency; do
            if ! command -v "${dependency}" &>/dev/null; then
                NOTFOUND="1"
                warn "Command '${dependency}' not found."
            fi
        done <<EOF
jq
envsubst
$ASED
EOF
    fi

    if [[ "${NOTFOUND}" == "1" ]]; then
        fatal "One or more prerequisites are not installed."
    fi
}


################################################################################
# Checks whether the required variables have been populated depending on the
# flags.
################################################################################
validate_args() {
    local VALIDATION_FAILED="0"


    if [[ "${CREATE_DEMO}" == "1" ]]; then
        if [[ -z "${ORGANIZATION_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--org is REQUIRED to auto-configure the demo"
        fi
    

    
    elif [[ "${ADD_CLUSTER}" == "1" ]]; then
        if [[ -z "${APIGEE_NAMESPACE}" ]]; then
            VALIDATION_FAILED="1"
            warn "--namespace is REQUIRED"
        fi
        if [[ -z "${ORGANIZATION_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--org is REQUIRED"
        fi
        if [[ -z "${CLUSTER_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-name is REQUIRED"
        fi
        if [[ -z "${CLUSTER_REGION}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-region is REQUIRED"
        fi
    
    

    elif [[ "${ADD_ENVIRONMENT}" == "1" ]]; then
        if [[ -z "${ORGANIZATION_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--org is REQUIRED"
        fi
        if [[ -z "${ENVIRONMENT_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--env is REQUIRED"
        fi
        if [[ -z "${APIGEE_NAMESPACE}" ]]; then
            VALIDATION_FAILED="1"
            warn "--namespace is REQUIRED"
        fi
        if [[ -z "${CLUSTER_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-name is REQUIRED"
        fi
        if [[ -z "${CLUSTER_REGION}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-region is REQUIRED"
        fi
    
    

    elif [[ "${ADD_ENVIRONGROUP}" == "1" ]]; then
        if [[ -z "${ORGANIZATION_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--org is REQUIRED"
        fi
        if [[ -z "${ENVIRONMENT_GROUP_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--envgroup is REQUIRED"
        fi
        if [[ -z "${ENVIRONMENT_GROUP_HOSTNAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--ingress-domain is REQUIRED"
        fi
        if [[ -z "${APIGEE_NAMESPACE}" ]]; then
            VALIDATION_FAILED="1"
            warn "--namespace is REQUIRED"
        fi
        if [[ -z "${CLUSTER_NAME}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-name is REQUIRED"
        fi
        if [[ -z "${CLUSTER_REGION}" ]]; then
            VALIDATION_FAILED="1"
            warn "--cluster-region is REQUIRED"
        fi



    elif [[ "${ENABLE_ADD_ON}" == "1" ]]; then
        case ${ADD_ON} in
            all)
                if [[ -z "${ORGANIZATION_NAME}" ]]; then
                    VALIDATION_FAILED="1"
                    warn "--org is REQUIRED"
                fi
                if [[ -z "${CLUSTER_REGION}" ]]; then
                    VALIDATION_FAILED="1"
                    warn "--cluster-region is REQUIRED"
                fi
                ;;
            openshift-scc)
                ;;
            env-group-extras)
                ;;
            environment-extras)
                ;;
            image-pull-secret)
                ;;
            node-selector)
                ;;
            workload-identity)
                ;;
            control-plane-http-proxy)
                ;;
            datastore-extras)
                if [[ -z "${ORGANIZATION_NAME}" ]]; then
                    VALIDATION_FAILED="1"
                    warn "--org is REQUIRED"
                fi
                if [[ -z "${CLUSTER_REGION}" ]]; then
                    VALIDATION_FAILED="1"
                    warn "--cluster-region is REQUIRED"
                fi
                ;;
            *)
                VALIDATION_FAILED="1"
                warn "Unrecognized Add-On name: ${ADD_ON}, please check spelling."
        esac

    fi



    if [[ "${VALIDATION_FAILED}" == "1" ]]; then
        error ""
        error "Attributes:"
        error "ORGANIZATION_NAME='${ORGANIZATION_NAME}'"
        error "ENVIRONMENT_GROUP_NAME='${ENVIRONMENT_GROUP_NAME}'"
        error "ENVIRONMENT_NAME='${ENVIRONMENT_NAME}'"
        error "CLUSTER_NAME='${CLUSTER_NAME}'"
        error "CLUSTER_REGION='${CLUSTER_REGION}'"
        error "APIGEE_NAMESPACE='${APIGEE_NAMESPACE}'"
        fatal "One or more validations failed. Exiting."
    fi
}


################################################################################
# Resolves flags
################################################################################
resolve_flags() {
    banner_info "Resolving Flags..."

    # if [[ "${SOMETHING IN THE FUTURE}" == "1" ]]; then

    # fi


}

################################################################################
# Tries to configure the default values of unset variables.
################################################################################
configure_vars() {
    banner_info "Configuring attributes..."

    readonly ORGANIZATION_NAME
    info "ORGANIZATION_NAME='${ORGANIZATION_NAME}'"

    if [[ "${CREATE_DEMO}" == "1" ]]; then

        APIGEE_NAMESPACE="${APIGEE_NAMESPACE:-"apigee"}"
        CLUSTER_NAME="${CLUSTER_NAME:-"demo-instance"}"
        CLUSTER_REGION="${CLUSTER_REGION:-"any-region"}"

        # Configure the Apigee API endpoint to be used for making API calls.
        local APIGEE_API_ENDPOINT_OVERRIDES
        APIGEE_API_ENDPOINT_OVERRIDES="$(gcloud config get-value api_endpoint_overrides/apigee)"
        if [[ "${APIGEE_API_ENDPOINT_OVERRIDES}" != "(unset)" && "${APIGEE_API_ENDPOINT_OVERRIDES}" != "" ]]; then
            APIGEE_API_ENDPOINT="${APIGEE_API_ENDPOINT_OVERRIDES}"
        fi
        readonly APIGEE_API_ENDPOINT
        info "APIGEE_API_ENDPOINT='${APIGEE_API_ENDPOINT}'"


        # Configure environment name
        local ENVIRONMENTS_LIST NUMBER_OF_ENVIRONMENTS
        ENVIRONMENTS_LIST="$(gcloud beta apigee environments list --organization="${ORGANIZATION_NAME}" --format='value(.)')"
        NUMBER_OF_ENVIRONMENTS=$(echo "${ENVIRONMENTS_LIST}" | wc -l)
        if [[ -z "${ENVIRONMENT_NAME}" ]]; then
            if ((NUMBER_OF_ENVIRONMENTS < 1)); then
                fatal "No environment exists in organization '${ORGANIZATION_NAME}'. Please create an environment and try again."
            elif ((NUMBER_OF_ENVIRONMENTS > 1)); then
                printf "Environments found:\n%s\n" "${ENVIRONMENTS_LIST}"
                fatal "Multiple environments found. Select one explicitly using --env and try again."
            fi
            ENVIRONMENT_NAME="$(echo "${ENVIRONMENTS_LIST}" | head --lines 1)"
        else
            local VALID_ENVIRONMENT="0"
            for ENVIRONMENT in ${ENVIRONMENTS_LIST[@]}; do
                if [[ "${ENVIRONMENT}" == "${ENVIRONMENT_NAME}" ]]; then
                    VALID_ENVIRONMENT="1"
                fi
            done
            if [[ "${VALID_ENVIRONMENT}" == "0" ]]; then
                printf "Environments found:\n%s\n" "${ENVIRONMENTS_LIST}"
                fatal "Invalid environment ${ENVIRONMENT_NAME} provided. Exiting."
            fi
        fi


        # Configure environment group name and hostname.
        #
        # Will only be executed when both envgroup and hostname are not set. Thus
        # the user is expected to either input both, or none of them.
        local RESPONSE ENVIRONMENT_GROUPS_LIST NUMBER_OF_ENVIRONMENT_GROUPS
        RESPONSE="$(
            run curl --fail --show-error --silent "${APIGEE_API_ENDPOINT}/v1/organizations/${ORGANIZATION_NAME}/envgroups/" \
                -K <(auth_header)
        )"
        NUMBER_OF_ENVIRONMENT_GROUPS=0
        if [[ "${RESPONSE}" != "{}" ]]; then
            ENVIRONMENT_GROUPS_LIST="$(echo "${RESPONSE}" | jq -r '.environmentGroups[].name')"
            NUMBER_OF_ENVIRONMENT_GROUPS=$(echo "${ENVIRONMENT_GROUPS_LIST}" | wc -l)
        fi
        if [[ -z "${ENVIRONMENT_GROUP_NAME}" && -z "${ENVIRONMENT_GROUP_HOSTNAME}" ]]; then
            if ((NUMBER_OF_ENVIRONMENT_GROUPS < 1)); then
                fatal "No environment group exists in organization '${ORGANIZATION_NAME}'. Please create an environment group and try again."
            elif ((NUMBER_OF_ENVIRONMENT_GROUPS > 1)); then
                printf "Environments groups found:\n%s\n" "${ENVIRONMENT_GROUPS_LIST}"
                fatal "Multiple environment groups found. Select one explicitly using --envgroup and try again."
            fi
            ENVIRONMENT_GROUP_NAME="$(echo "${RESPONSE}" | jq -r '.environmentGroups[0].name')"
            ENVIRONMENT_GROUP_HOSTNAME="$(echo "${RESPONSE}" | jq -r '.environmentGroups[0].hostnames[0]')"
        else
            local VALID_ENVIRONMENT_GROUP="0"
            for ENVIRONMENT_GROUP in ${ENVIRONMENT_GROUPS_LIST[@]}; do
                if [[ "${ENVIRONMENT_GROUP}" == "${ENVIRONMENT_GROUP_NAME}" ]]; then
                    VALID_ENVIRONMENT_GROUP="1"
                fi
            done
            if [[ "${VALID_ENVIRONMENT_GROUP}" == "0" ]]; then
                printf "Environments groups found:\n%s\n" "${ENVIRONMENT_GROUPS_LIST}"
                fatal "Invalid environment group ${ENVIRONMENT_GROUP_NAME} provided. Exiting."
            fi
        fi

    fi

    readonly ENVIRONMENT_NAME
    info "ENVIRONMENT_NAME='${ENVIRONMENT_NAME}'"

    readonly ENVIRONMENT_GROUP_NAME ENVIRONMENT_GROUP_HOSTNAME
    info "ENVIRONMENT_GROUP_NAME='${ENVIRONMENT_GROUP_NAME}'"
    info "ENVIRONMENT_GROUP_HOSTNAME='${ENVIRONMENT_GROUP_HOSTNAME}'"

    readonly APIGEE_NAMESPACE
    info "APIGEE_NAMESPACE='${APIGEE_NAMESPACE}'"

    readonly CLUSTER_NAME
    info "CLUSTER_NAME='${CLUSTER_NAME}'"

    readonly CLUSTER_REGION
    info "CLUSTER_REGION='${CLUSTER_REGION}'"

    # Configure GCP Project ID name
    if [[ -z "${GCP_PROJECT_ID}" ]]; then
        GCP_PROJECT_ID="${ORGANIZATION_NAME}"
    fi
    readonly GCP_PROJECT_ID
    info "GCP_PROJECT_ID='${GCP_PROJECT_ID}'"

    INSTANCE_DIR="${ROOT_DIR}/overlays/instances/${CLUSTER_NAME}-${CLUSTER_REGION}"
    readonly INSTANCE_DIR
}

################################################################################
# Parse command line arguments.
################################################################################
parse_args() {
    while [[ $# != 0 ]]; do
        case "${1}" in
        add)
            arg_required "${@}"
#            ORGANIZATION_NAME="${2}"
            case "${2}" in
                cluster)
                    ADD_CLUSTER="1"
                    readonly ADD_CLUSTER
                    ;;
                environment-group)
                    ADD_ENVIRONGROUP="1"
                    readonly ADD_ENVIRONGROUP
                    ;;
                environment)
                    ADD_ENVIRONMENT="1"
                    readonly ADD_ENVIRONMENT
                    ;;
                *)
                    fatal "Unknown Command Entity '${2}'. Only {cluster | environment-group | environment} are supported."
                    ;;
            esac
            shift 2
            ;;
        check)
            arg_required "${@}"
            CHECK_ALL="1"
            readonly CHECK_ALL
            shift 2
            ;;
        print-yaml)
            arg_required "${@}"
            PRINT_YAML_ALL="1"
            readonly PRINT_YAML_ALL
            shift 2
            ;;
        create)
            arg_required "${@}"
            CREATE_DEMO="1"
            readonly CREATE_DEMO
            shift 2
            ;;
        enable)
            arg_required "${@}"
            ENABLE_ADD_ON="1"
            ADD_ON="${2}"
            readonly ENABLE_ADD_ON
            readonly ADD_ON
            shift 2
            ;;
        --org)
            arg_required "${@}"
            ORGANIZATION_NAME="${2}"
            shift 2
            ;;
        --env)
            arg_required "${@}"
            ENVIRONMENT_NAME="${2}"
            shift 2
            ;;
        --envgroup)
            arg_required "${@}"
            ENVIRONMENT_GROUP_NAME="${2}"
            shift 2
            ;;
        --ingress-domain)
            arg_required "${@}"
            ENVIRONMENT_GROUP_HOSTNAME="${2}"
            shift 2
            ;;
        --namespace)
            arg_required "${@}"
            APIGEE_NAMESPACE="${2}"
            shift 2
            ;;
        --cluster-name)
            arg_required "${@}"
            CLUSTER_NAME="${2}"
            shift 2
            ;;
        --cluster-region)
            arg_required "${@}"
            CLUSTER_REGION="${2}"
            shift 2
            ;;
        --gcp-project-id)
            arg_required "${@}"
            GCP_PROJECT_ID="${2}"
            shift 2
            ;;
        --verbose)
            VERBOSE="1"
            readonly VERBOSE
            shift 1
            ;;
        --diagnostic)
            DIAGNOSTIC="1"
            readonly DIAGNOSTIC
            shift 1
            ;;
        --help)
            usage
            exit
            ;;
        --version)
            echo "Apigee Hybrid Setup Version: ${APIGEE_HYBRID_VERSION}"
            exit
            ;;
        *)
            fatal "Unknown option '${1}'"
            ;;
        esac
    done

}

################################################################################
# Print help text.
################################################################################
usage() {
    local COMMANDS_0 ATTRIB_1 FLAGS_2

    # Available commands
    COMMANDS_0="$(
        cat <<EOF
    COMMAND     ENTITY              NOTES
    ---------   -----------         ---------
    add                             Adds specified entity to the /overrides folder.
                cluster             -- Add cluster (without environment/group)
                environment         -- Add environment (prerequisite: cluster)
                environment-group   -- Add environment group (prerequisite: cluster)
                
    check       all                 Confirms that at least 1 cluster, 1 environment,
                                    and 1 environment group has been added. Also check
                                    for placeholder variables that have not be set.
                                    
    print-yaml  all                 Prints all core yaml manifests as configured
                                    However, this will NOT PRINT the yamls for:
                                    Service Accounts and Secrets
                                    
    create      demo                Creates a pre-configured Demo setup that Auto
                                    configures with a Single EnvironmentGroup & Environment
                                    reading information from the Apigee Organization (Mgmt Plane)
                                    and creating and configuring a non-prod Service Account
                                    NOTEs:
                                    1) curl is required
                                    2) the user executing [create demo] must have a
                                    valid GCP account and gcloud installed and configured

    enable                          Adds patch files that enable specified feature
                                    !! CRITICAL: many add-ons require variables or fields
                                    to be filled in manually. Please review all added files!
                                    The standard variable replacement may not work correctly
        all                         -- Adds all available feature patches
        openshift-scc               -- Adds SecurityContextConstraints needed for OpenShift 
        image-pull-secret           -- Adds support for private repository
        node-selector               -- Adds node selector patches
        workload-identity           -- Adds Google Workload Identity configuration
        control-plane-http-proxy    -- Adds Forward Proxy to Control Plane support
        env-group-extras            -- Adds a collection of common Environment Group configurations
        environment-extras          -- Adds a collection of common Environment configurations
        datastore-extras            -- Adds a collection of common DataStore configurations
                                        
EOF
    )"

    # Flags that require an argument
    ATTRIB_1="$(
        cat <<EOF
    ATTRIBUTE         VALUE                         NOTES
    -----------       -----------                   ---------
    --org             <ORGANIZATION_NAME>           Set the Apigee Organization.
                                                    If not set, the project configured
                                                    in gcloud will be used.
    --env             <ENVIRONMENT_NAME>            Set the Apigee Environment.
                                                    If not set, a random environment
                                                    within the organization will be
                                                    selected.
    --envgroup        <ENVIRONMENT_GROUP_NAME>      Set the Apigee Environment Group.
                                                    If not set, a random environment
                                                    group within the organization
                                                    will be selected.
    --ingress-domain  <ENVIRONMENT_GROUP_HOSTNAME>  Set the hostname. This will be
                                                    used to generate self signed
                                                    certificates.
    --namespace       <APIGEE_NAMESPACE>            The name of the namespace where
                                                    apigee components will be installed.
                                                    Defaults to "apigee".
    --cluster-name    <CLUSTER_NAME>                The Kubernetes cluster name.
    --cluster-region  <CLUSTER_REGION>              The region in which the
                                                    Kubernetes cluster resides.
    --gcp-project-id  <GCP_PROJECT_ID>              The GCP Project ID where the
                                                    Kubernetes cluster exists.
                                                    This can be different from
                                                    the Apigee Organization name.
EOF
    )"

    # Flags that DON'T require an argument
    FLAGS_2="$(
        cat <<EOF
    --non-production <default>   Configuration is for non-prod environments.
    --verbose                    Show detailed output for debugging.
    --version                    Display version of apigee hybrid setup.
    --help                       Display usage information.
EOF
    )"

    cat <<EOF

${SCRIPT_NAME}

USAGE: ${SCRIPT_NAME} [command entity] [attributes] [flags]

The setup script helps build the manifest structure needed to deploy Apigee. The structure
requires a minimum of 1 cluster, 1 environment group, and 1 environment. Setup supports adding
additional clusters, environment groups, and environments as needed to fully represent the 
Apigee Organization.

Once an Entity is added, it can be customized using standard Kubernetes Kustomize practices.

!!!CRITICAL NOTE: The currently available configurations are designed for non-production
environments. Production environment configurations are on the roadmap.

The setup script can also enable a variety of standard customizations. These are added in
the form of patches to the /overrides structure.
    CRITICAL NOTE: Setup up is not "smart". If a customization is added. Then later an additional
    environment or other entity is added. The customization(s) will not have been applied to
    the newly added Entity structure.

General use will require a minimum of three steps:
1) Add a cluster
2) Add an environment group
3) Add an environment
A minumum of the above three steps must be performed for Apigee to install properly. The check
function can be used to confirm these have been applied.


REQUIRED command list:

$COMMANDS_0

REQUIRED attributes (varies by Command):

$ATTRIB_1

Additional flags:

$FLAGS_2

EXAMPLES:

Basic setup (requires all 3 runs):

./apigee-hybrid-setup.sh add cluster \\
    --namespace apigee \\
    --org my-organization-name \\
    --cluster-name apigee-hybrid-cluster \\
    --cluster-region us-west1

./apigee-hybrid-setup.sh add environment-group \\
    --namespace apigee \\
    --org my-organization-name \\
    --cluster-name apigee-hybrid-cluster \\
    --cluster-region us-west1
    --envgroup dev-environments \\
    --ingress-domain dev.mycompany.com \\

./apigee-hybrid-setup.sh add environment \\
    --namespace apigee \\
    --org my-organization-name \\
    --cluster-name apigee-hybrid-cluster \\
    --cluster-region us-west1 \\
    --env dev01


Configure a basic demo configuration for Hybrid
pulling information from the control plane:

./apigee-hybrid-setup.sh create demo\\
    --org my-organization-name \\
    --cluster-name apigee-hybrid-cluster \\
    --cluster-region us-west1

EOF
}

################################################################################
# run takes a list of arguments that represents a command.
# If VERBOSE is enabled, it will print and run the command.
################################################################################
run() {
    if [[ "${VERBOSE}" -eq 0 ]]; then
        "${@}" 2>/dev/null
        return "$?"
    fi

    info "Running: '${*}'"
    local RETVAL
    {
        "${@}"
        RETVAL="$?"
    } || true
    return $RETVAL
}

################################################################################
# Wrapper functions
#
# These functions wrap other utilities with the `run` function for supporting
# --verbose
################################################################################
gcloud() {
    run "${AGCLOUD}" "${@}"
}

sed() {
    run "${ASED}" "${@}"
}

################################################################################
# Returns the authorization header to be used with curl commands.
# This when used in conjunction with the -K flag keeps the token from printing
# if this script is run with --verbose
################################################################################
auth_header() {
    local TOKEN
    TOKEN="$(gcloud --project="${ORGANIZATION_NAME}" auth print-access-token)"
    echo "--header \"Authorization: Bearer ${TOKEN}\""
}

warn() {
    info "[WARNING]: ${1}" >&2
}

fatal() {
    error "${1}"
    exit 2
}

error() {
    info "[ERROR]: ${1}" >&2
}

banner_info() {
    echo ""
    info "********************************************"
    info "${1}"
    info "********************************************"
}

info() {
    if [[ "${VERBOSE}" -eq 1 && "${HAS_TS}" -eq 1 ]]; then
        echo "${SCRIPT_NAME}: ${1}" | TZ=utc ts '%Y-%m-%dT%.T' >&2
    else
        echo "${SCRIPT_NAME}: ${1}" >&2
    fi
}

exit_handler() {
    if (($? != 0)); then
        banner_info "FAILED."
        info "Please try again and possibly use '--verbose' flag to debug if error persists."
        exit 1
    fi
}

trap exit_handler EXIT

main "${@}"
