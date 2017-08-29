# Terminator: Easy TLS (SSL) termination and reverse-proxy for cloud deployments

The general idea is that TLS termination and reverse proxying should be
achievable through minimal configuration by adding a simple container that knows
how to get the required information from your cloud, and reconfigure on-the-fly
when things change.

### Assumptions
- All domains (bare, www., etc.) are specified in metadata, e.g. in labels
- All domains have correct nameserver mappings
- No www. forwarding occurs
- All domains can be tied to a single Let's Encrypt email address
- ACME is good enough, i.e. all configured domains pass through to services
  hosted in the cloud infrastructure


### Supported cloud infrastructure
- [Rancher](http://rancher.com/)

I'll add more as required.


### Based on
- [Docker](https://www.docker.com/)
- [Alpine Linux](https://alpinelinux.org/)
- [Caddy](https://caddyserver.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- [curl](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
