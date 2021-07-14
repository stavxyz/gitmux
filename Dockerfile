FROM alpine:3.14

ARG GH_VERSION
ENV GH_VERSION ${GH_VERSION:-1.12.1}
WORKDIR /gitmux

COPY gitmux.sh .

# Install dependencies
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    bash \
    git \
    openssh \
    jq

# Install the GitHub CLI
RUN wget https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz && \
    tar -xf gh_${GH_VERSION}_linux_amd64.tar.gz && \
    ln -s /gitmux/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh && \
    rm /gitmux/gh_${GH_VERSION}_linux_amd64.tar.gz
