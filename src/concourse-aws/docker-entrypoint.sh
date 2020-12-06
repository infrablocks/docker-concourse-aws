#!/usr/bin/dumb-init /bin/bash

set -e
set -o pipefail

# Define helper functions used in script
ensure_env_var_set () {
    local name="$1"
    if [ -z "${!name}" ]; then
        echo >&2 "Error: missing ${name} environment variable."
        return 1
    fi
}

source_callback () {
    local name="$1"
    if [ -n "${!name}" ]; then
        echo >&2 "Sourcing callback. [path: ${!name}]"
        # shellcheck disable=SC1090
        source "${!name}"
    fi
}

exec_callback () {
    local name="$1"
    shift
    echo >&2 "Exec'ing callback. [path: ${!name}]"
    exec "${!name}" "$@"
}

# Ensure required env vars set and default optional env vars
ensure_env_var_set "AWS_S3_BUCKET_REGION"
ensure_env_var_set "AWS_S3_ENV_FILE_OBJECT_PATH"

AWS_DEFAULT_S3_ENDPOINT_URL="https://s3.${AWS_S3_BUCKET_REGION}.amazonaws.com"
AWS_DEFAULT_METADATA_SERVICE_URL="http://169.254.169.254"

AWS_S3_ENDPOINT_URL="${AWS_S3_ENDPOINT_URL:-${AWS_DEFAULT_S3_ENDPOINT_URL}}"
AWS_METADATA_SERVICE_URL=\
"${AWS_METADATA_SERVICE_URL:-${AWS_DEFAULT_METADATA_SERVICE_URL}}"

export AWS_S3_BUCKET_REGION
export AWS_S3_ENV_FILE_OBJECT_PATH
export AWS_S3_ENDPOINT_URL
export AWS_METADATA_SERVICE_URL

# Define more helper functions using in script
fetch_value_from_metadata_service () {
    local metadata_service_url="${AWS_METADATA_SERVICE_URL}"
    local key="$1"

    local key_kv="key: $key"
    local metadata_service_url_kv="metadata-service-url: $metadata_service_url"

    echo >&2 "Looking up instance metadata. [$metadata_service_url_kv, $key_kv]"
    curl -s "${metadata_service_url}/latest/meta-data/$key"
}

fetch_env_file_contents_from_s3 () {
    local endpoint_url="${AWS_S3_ENDPOINT_URL}"
    local region="$1"
    local object_path="$2"

    local endpoint_url_kv="endpoint-url: ${endpoint_url}"
    local region_kv="region: ${region}"
    local object_path_kv="object-path: ${object_path}"
    local details="[${endpoint_url_kv}, ${region_kv}, ${object_path_kv}]"

    echo >&2 "Fetching and transforming env file from S3. ${details}"
    aws \
        --endpoint-url "${endpoint_url}" \
        s3 cp \
        --sse AES256 \
        --region "${region}" \
        "${object_path}" -
}

# Define helper functions used in callbacks
fetch_file_from_s3 () {
    local endpoint_url="${AWS_S3_ENDPOINT_URL}"
    local region="$1"
    local object_path="$2"
    local local_path="$3"

    local endpoint_url_kv="endpoint-url: ${endpoint_url}"
    local region_kv="region: ${region}"
    local object_path_kv="object-path: ${object_path}"
    local local_path_kv="local-path: ${local_path}"
    local paths_kvs="${object_path_kv}, ${local_path_kv}"
    local details="[${endpoint_url_kv}, ${region_kv}, ${paths_kvs}]"

    echo >&2 "Fetching file from S3. ${details}"
    mkdir -p "$(dirname "$local_path")"
    aws \
        --endpoint-url "${endpoint_url}" \
        s3 cp \
        --sse AES256 \
        --region "${region}" \
        "${object_path}" \
        "${local_path}"
}

add_env_var () {
    local name="$1"
    local value="$2"

    echo >&2 "Adding environment variable. [name: ${name}]"
    export "${name}"="${value}"
}

# Expose host details
SELF_ID=$(fetch_value_from_metadata_service "instance-id")
SELF_IP=$(fetch_value_from_metadata_service "local-ipv4")
SELF_HOSTNAME=$(fetch_value_from_metadata_service "local-hostname")
SELF_AVAILABILITY_ZONE=$(fetch_value_from_metadata_service "placement/availability-zone")

export SELF_ID
export SELF_IP
export SELF_HOSTNAME
export SELF_AVAILABILITY_ZONE

# Fetch and source env file from S3
set -o allexport
eval "$(fetch_env_file_contents_from_s3 \
        "${AWS_S3_BUCKET_REGION}" \
        "${AWS_S3_ENV_FILE_OBJECT_PATH}")"
set +o allexport

# Fetch secrets files
export -f fetch_file_from_s3
source_callback "FETCH_SECRETS_FILES_SCRIPT_PATH"
export -n -f fetch_file_from_s3

# Export additional environment
export -f add_env_var
source_callback "EXPORT_ADDITIONAL_ENVIRONMENT_SCRIPT_PATH"
export -n -f add_env_var

# Delegate to startup script
export -f fetch_file_from_s3 add_env_var
exec_callback "STARTUP_SCRIPT_PATH" "$@"
export -n -f fetch_file_from_s3 add_env_var
