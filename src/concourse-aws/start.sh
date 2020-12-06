#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

CONCOURSE_SESSION_SIGNING_KEY=\
"${CONCOURSE_SESSION_SIGNING_KEY:-/concourse-keys/session_signing_key}"
if [ -f "$CONCOURSE_SESSION_SIGNING_KEY" ]; then
  export CONCOURSE_SESSION_SIGNING_KEY
fi

CONCOURSE_TSA_AUTHORIZED_KEYS=\
"${CONCOURSE_TSA_AUTHORIZED_KEYS:-/concourse-keys/authorized_worker_keys}"
if [ -f "$CONCOURSE_TSA_AUTHORIZED_KEYS" ]; then
  export CONCOURSE_TSA_AUTHORIZED_KEYS
fi

CONCOURSE_TSA_HOST_KEY=\
"${CONCOURSE_TSA_HOST_KEY:-/concourse-keys/tsa_host_key}"
if [ -f "$CONCOURSE_TSA_HOST_KEY" ]; then
  export CONCOURSE_TSA_HOST_KEY
fi

CONCOURSE_TSA_PUBLIC_KEY=\
"${CONCOURSE_TSA_PUBLIC_KEY:-/concourse-keys/tsa_host_key.pub}"
if [ -f "$CONCOURSE_TSA_PUBLIC_KEY" ]; then
  export CONCOURSE_TSA_PUBLIC_KEY
fi

CONCOURSE_TSA_WORKER_PRIVATE_KEY=\
"${CONCOURSE_TSA_WORKER_PRIVATE_KEY:-/concourse-keys/worker_key}"
if [ -f "$CONCOURSE_TSA_WORKER_PRIVATE_KEY" ]; then
  export CONCOURSE_TSA_WORKER_PRIVATE_KEY
fi

echo "Running concourse."
exec /usr/local/concourse/bin/concourse "$@"
