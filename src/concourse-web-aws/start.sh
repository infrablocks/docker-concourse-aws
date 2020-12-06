#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

peer_address="${CONCOURSE_PEER_ADDRESS:-${SELF_IP}}"

session_signing_key_option=
if [ -n "${CONCOURSE_SESSION_SIGNING_KEY_FILE_OBJECT_PATH}" ]; then
  default_path=/opt/concourse/conf/session-signing-key
  echo "Fetching session signing key."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${CONCOURSE_SESSION_SIGNING_KEY_FILE_OBJECT_PATH}" \
    "${default_path}"
  session_signing_key_option="--session-signing-key=${default_path}"
fi
if [ -n "${CONCOURSE_SESSION_SIGNING_KEY_FILE_PATH}" ]; then
  file_path="${CONCOURSE_SESSION_SIGNING_KEY_FILE_PATH}"
  session_signing_key_option="--session-signing-key=${file_path}"
fi

tsa_host_key_option=
if [ -n "${CONCOURSE_TSA_HOST_KEY_FILE_OBJECT_PATH}" ]; then
  default_path=/opt/concourse/conf/tsa-host-key
  echo "Fetching TSA host key."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${CONCOURSE_TSA_HOST_KEY_FILE_OBJECT_PATH}" \
    "${default_path}"
  tsa_host_key_option="--tsa-host-key=${default_path}"
fi
if [ -n "${CONCOURSE_TSA_HOST_KEY_FILE_PATH}" ]; then
  file_path="${CONCOURSE_TSA_HOST_KEY_FILE_PATH}"
  tsa_host_key_option="--tsa-host-key=${file_path}"
fi

tsa_authorized_keys_option=
if [ -n "${CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_OBJECT_PATH}" ]; then
  default_path=/opt/concourse/conf/tsa-authorized-keys
  echo "Fetching TSA authorized keys."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_OBJECT_PATH}" \
    "${default_path}"
  tsa_authorized_keys_option="--tsa-authorized-keys=${default_path}"
fi
if [ -n "${CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_PATH}" ]; then
  file_path="${CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_PATH}"
  tsa_authorized_keys_option="--tsa-authorized-keys=${file_path}"
fi

# shellcheck disable=SC2086
exec /opt/concourse/bin/start.sh web \
    --peer-address="${peer_address}" \
    \
    ${session_signing_key_option} \
    \
    ${tsa_host_key_option} \
    ${tsa_authorized_keys_option} \
    \
    "$@"
