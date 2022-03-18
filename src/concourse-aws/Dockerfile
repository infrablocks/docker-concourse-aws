FROM concourse/concourse:7.7.0 as concourse

FROM ubuntu:focal-20220316

# Install dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    dumb-init \
    iproute2 \
    file \
    iptables

# Fetch binaries from base image
COPY --from=concourse /usr/local/concourse /opt/concourse

# Use similar configuration to base image
ENV CONCOURSE_GARDEN_DNS_PROXY_ENABLE=true
ENV CONCOURSE_WORKER_GARDEN_DNS_PROXY_ENABLE=true

STOPSIGNAL SIGUSR2

# Install AWS CLI
RUN apt-get update \
    && apt-get -y install python-is-python3 python3-venv curl unzip \
    && cd /tmp \
    && curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" \
    && unzip awscli-bundle.zip \
    && ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws \
    && rm awscli-bundle.zip \
    && rm -rf awscli-bundle

# Configure entrypoints
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY start.sh /opt/concourse/bin/start.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /opt/concourse/bin/start.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

ENV STARTUP_SCRIPT_PATH=/opt/concourse/bin/start.sh
