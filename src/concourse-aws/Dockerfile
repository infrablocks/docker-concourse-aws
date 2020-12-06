FROM concourse/concourse:6.7.2

# Install AWS CLI
RUN apt-get update \
    && apt-get -y install python curl unzip \
    && cd /tmp \
    && curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" \
    && unzip awscli-bundle.zip \
    && ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws \
    && rm awscli-bundle.zip \
    && rm -rf awscli-bundle

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY start.sh /usr/local/concourse/bin/start.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/concourse/bin/start.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

ENV STARTUP_SCRIPT_PATH=/usr/local/concourse/bin/start.sh
