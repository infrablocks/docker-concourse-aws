ARG BASE_IMAGE_VERSION
FROM infrablocks/concourse-aws:$BASE_IMAGE_VERSION

COPY start.sh /opt/concourse/bin/web-start.sh

RUN chmod +x /opt/concourse/bin/web-start.sh

ENV STARTUP_SCRIPT_PATH=/opt/concourse/bin/web-start.sh
