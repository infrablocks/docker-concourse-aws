ARG BASE_IMAGE_VERSION
FROM infrablocks/concourse-aws:$BASE_IMAGE_VERSION

COPY start.sh /usr/local/concourse/bin/worker-start.sh

RUN chmod +x /usr/local/concourse/bin/worker-start.sh

ENV STARTUP_SCRIPT_PATH=/usr/local/concourse/bin/worker-start.sh
