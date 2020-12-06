#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

exec /opt/concourse/bin/start.sh worker \
    \
    "$@"
