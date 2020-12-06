#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

tsa_worker_private_key_option=
if [ -n "${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_OBJECT_PATH}" ]; then
  default_path=/opt/concourse/conf/tsa-worker-private-key
  echo "Fetching TSA worker private key."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_OBJECT_PATH}" \
    "${default_path}"
  tsa_worker_private_key_option="--tsa-worker-private-key=${default_path}"
fi
if [ -n "${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH}" ]; then
  file_path="${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH}"
  tsa_worker_private_key_option="--tsa-worker-private-key=${file_path}"
fi

tsa_public_key_option=
if [ -n "${CONCOURSE_TSA_PUBLIC_KEY_FILE_OBJECT_PATH}" ]; then
  default_path=/opt/concourse/conf/tsa-public-key
  echo "Fetching TSA public key."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${CONCOURSE_TSA_PUBLIC_KEY_FILE_OBJECT_PATH}" \
    "${default_path}"
  tsa_public_key_option="--tsa-public-key=${default_path}"
fi
if [ -n "${CONCOURSE_TSA_PUBLIC_KEY_FILE_PATH}" ]; then
  file_path="${CONCOURSE_TSA_PUBLIC_KEY_FILE_PATH}"
  tsa_public_key_option="--tsa-public-key=${file_path}"
fi

# shellcheck disable=SC2086
exec /opt/concourse/bin/start.sh worker \
    \
    ${tsa_public_key_option} \
    ${tsa_worker_private_key_option} \
    \
    "$@"
