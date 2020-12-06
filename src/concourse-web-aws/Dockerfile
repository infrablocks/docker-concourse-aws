ARG BASE_IMAGE_VERSION
FROM infrablocks/concourse-aws:$BASE_IMAGE_VERSION

COPY start.sh /usr/local/concourse/bin/web-start.sh

RUN chmod +x /usr/local/concourse/bin/web-start.sh

ENV STARTUP_SCRIPT_PATH=/usr/local/concourse/bin/web-start.sh
