# Frontier: Easy TLS (SSL) termination and reverse-proxy for cloud deployments

The general idea is that TLS termination and reverse proxying should be
achievable through minimal configuration by adding a simple container that knows
how to get the required information from your cloud, and reconfigure on-the-fly
when things change.

Using this container implies that you agree to the [Let's Encrypt terms of
service](https://community.letsencrypt.org/tos).

### Assumptions
- All domains (bare, www., etc.) are specified in metadata, e.g. in labels
- All domains have correct nameserver mappings
- No www. forwarding occurs
- All domains can be tied to a single Let's Encrypt email address
- ACME is good enough, i.e. all configured domains pass through to services
  hosted in the cloud infrastructure
- The number of hosts is in the tens, not the hundreds or thousands
- The Frontier container has direct internet access to communicate with Let's
  Encrypt
- No duplicate domain labels are found in the network
- HTTP proxying only, i.e. the network is trusted so HTTPS communication is not
  needed
- Bridge network is good enough for most use-cases (even though docker-compose
  2+ creates a network per container by default)


### Installation

Run inside a virtual network with access to the metadata required (e.g. having
access to the Docker socket, or Rancher metadata server). Make this container
the entrypoint to all HTTP(S) traffic by pointing all traffic on ports 80 and
443 to its exposed ports of the same numbers. Make sure to bind the /state
volume in order to keep track of the certificates received from Let's Encrypt
across container restarts/removal.

Set labels of "frontier.domains" and "frontier.port" to a comma-separated list
of domains that should point to the container, and the HTTP port to listen on.

#### Example docker-compose.yml

    frontier:
        image: lunarcity7/frontier:latest
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
            - ./frontier_state:/state
        restart: always
        ports:
            - "80:80"
            - "443:443"
        command: foo@bar.com docker-socket /var/run/docker.sock

    portainer:
      image: portainer/portainer:latest
      privileged: true
      restart: always
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - ./data:/data
      labels:
        - "frontier.domains=portainer.mydomain.com, otherurl.mydomain.com"
        - "frontier.port=9000"

#### Create state dir

    $ mkdir frontier_state
    $ chmod 777 frontier_state


#### Run docker-compose

    $ docker-compose up -d
    $ docker-compose logs frontier


#### Simple password protection

A simple network-wide user/pass combination can be set and containers can be
tagged to use this:

    frontier:
        image: lunarcity7/frontier:latest
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
            - ./frontier_state:/state
        restart: always
        ports:
            - "80:80"
            - "443:443"
        command: foo@bar.com docker-socket /var/run/docker.sock
        environment:
            FRONTIER_USER: username
            FRONTIER_PASS: password

    diary:
      image: ghost:latest
      restart: always
      labels:
        - "frontier.domains=diary.mydomain.com"
        - "frontier.port=2368"
        - "frontier.tags=login"

Note that if either user/pass is not specified in environment variables,
Frontier will auto-generate 32-character passwords and output these to the logs.


#### Docker compose 2+

When using later versions for `docker-compose`, make sure to add `network_mode:
"bridge"` to the container you wish to expose.


### Supported infrastructure
- Docker socket
- [Rancher](http://rancher.com/)


### Likely next-steps
- Add support for other metadata sources, e.g. Swarm, Consul
- Remove assumptions where possible


### Based on
- [Docker](https://www.docker.com/)
- [Alpine Linux](https://alpinelinux.org/)
- [Caddy](https://caddyserver.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- [curl](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
