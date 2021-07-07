FROM alpine:3.14

ARG GH_VERSION
ENV GH_VERSION ${GH_VERSION:-1.12.1}

RUN apk update && apk upgrade
RUN apk add --no-cache bash git openssh jq

RUN wget https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz
RUN tar -xf gh_${GH_VERSION}_linux_amd64.tar.gz
RUN ln -s /gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh
