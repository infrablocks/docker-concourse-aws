#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

exec /usr/local/concourse/bin/start.sh web \
    \
    "$@"
