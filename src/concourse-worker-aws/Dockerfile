ARG BASE_IMAGE_VERSION
FROM infrablocks/concourse-aws:$BASE_IMAGE_VERSION

COPY start.sh /opt/concourse/bin/worker-start.sh

RUN chmod +x /opt/concourse/bin/worker-start.sh

ENV STARTUP_SCRIPT_PATH=/opt/concourse/bin/worker-start.sh
