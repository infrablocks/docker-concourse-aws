#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

tsa_worker_private_key_option=
if [ -n "${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH}" ]; then
  file_path="${CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH}"
  tsa_worker_private_key_option="--tsa-worker-private-key=${file_path}"
fi

# shellcheck disable=SC2086
exec /opt/concourse/bin/start.sh worker \
    \
    ${tsa_worker_private_key_option} \
    \
    "$@"
