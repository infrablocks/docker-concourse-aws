#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

echo "Running concourse."
exec /usr/local/concourse/bin/concourse "$@"
