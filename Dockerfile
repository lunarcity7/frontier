FROM alpine:3

ARG caddy="https://caddyserver.com/api/download?os=linux&arch=amd64&idempotency=38592062657469"
ARG build_deps="ca-certificates"
ARG run_deps="dumb-init curl jq libcap sudo socat"

RUN \
    apk --update add \
         $build_deps \
         $run_deps \
         && \
    \
    cd /tmp && \
    curl -L $caddy > /caddy && \
    chmod 755 /caddy && \
    setcap cap_net_bind_service=+ep /caddy && \
    rm -rf /tmp/* && \
    \
    mkdir /state && \
    \
    apk del $build_deps && \
    rm -rf /var/cache/apk/*

EXPOSE 80 443
WORKDIR /tmp
VOLUME /state
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint.sh"]

ADD entrypoint.sh /
ADD daemon.sh /
