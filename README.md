# Frontier: Easy TLS (SSL) termination and reverse-proxy for cloud deployments

The general idea is that TLS termination and reverse proxying should be
achievable through minimal configuration by adding a simple container that knows
how to get the required information from your cloud, and reconfigure on-the-fly
when things change.

Using this container impliest that you agree to the [Let's Encrypt terms of
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


### Installation

Run inside a virtual network with access to the metadata required (e.g. Rancher
metadata server). Make this container the entrypoint to all HTTP(S) traffic by
pointing all traffic on ports 80 and 443 to its exposed ports of the same
numbers. Make sure to bind the /state volume in order to keep track of the
certificates received from Let's Encrypt across container restarts/removal.

Set labels of "trp.domains" and "trp.port" to a comma-separated list of domains
that should point to the container, and the HTTP port to listen on.

#### Example docker-compose.yml

    frontier:
        image: lunarcity7/frontier:latest
        volumes:
            - ./frontier_state:/state
        restart: always
        ports:
            - "80:80"
            - "443:443"
        command: foo@bar.com rancher 172.17.0.3

    othercontainer:
        labels:
            trp.domains: "www.domain1.com, domain1.com"
            trp.port: "2015"

#### Create state dir

    $ mkdir frontier_state
    $ chmod 777 frontier_state


#### Run docker-compose

    $ docker-compose up -d
    $ docker-compose logs frontier


### Supported cloud infrastructure
- [Rancher](http://rancher.com/)


### Likely next-steps
- Add support for other metadata sources, e.g. Docker socket, Swarm, Consul
- Remove assumptions where possible


### Based on
- [Docker](https://www.docker.com/)
- [Alpine Linux](https://alpinelinux.org/)
- [Caddy](https://caddyserver.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- [curl](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
