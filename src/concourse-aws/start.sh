#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

echo "Running concourse."
exec /opt/concourse/bin/concourse "$@"
