ARG INSTALL_CONCOURSE_VERSION="6.7.2"

FROM concourse/concourse:${INSTALL_CONCOURSE_VERSION}

ENV CONCOURSE_VERSION ${INSTALL_CONCOURSE_VERSION}

# Install AWS CLI
RUN apt-get update \
    && apt-get -y install python curl unzip \
    && cd /tmp \
    && curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" \
    && unzip awscli-bundle.zip \
    && ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws \
    && rm awscli-bundle.zip \
    && rm -rf awscli-bundle
