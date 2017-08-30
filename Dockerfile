FROM alpine:3.6

ENV \
    caddy="https://github.com/mholt/caddy/releases/download/v0.10.7/caddy_v0.10.7_linux_amd64.tar.gz" \
    build="ca-certificates" \
    run="curl jq libcap"

RUN \
    apk --update add \
         $build \
         $run \
         && \
    \
    cd /tmp && \
    curl -L $caddy > caddy.tar.gz && \
    tar zxf * && \
    mv caddy /usr/local/bin && \
    setcap cap_net_bind_service=+ep /usr/local/bin/caddy && \
    rm -rf /tmp/* && \
    \
    mkdir /state && \
    \
    apk del $build && \
    rm -rf /var/cache/apk/*

EXPOSE 80 443
WORKDIR /tmp
ENV CADDYPATH="/state"
VOLUME /state
ENTRYPOINT ["/entrypoint.sh"]

ADD entrypoint.sh /

USER nobody
