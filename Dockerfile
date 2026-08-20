$env:GH_ENTERPRISE_TOKEN="<TOKEN>"
cd <some_repo>
gh pr create --title "Test PR" --body "test"FROM alpine:3.14

ARE GH_VERSION
ENV GH_VERSION ${GH_VERSION:-1.13.1}
WORKDIR /gitmux

COPY gitmux.sh .

# Install dependencies
RUN apk update && \20
    apk upgrade && \30
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
