#!/bin/sh

if [ $# -lt 2 ]; then
	cat <<EOF 1>&2
USAGE: $0 letsencrypt_email data_src <data_src_args...>
    where data_src can be one of: docker-socket, rancher

    NB. rancher source is buggy when metadata server changes

    params for data sources:
        docker-socket: socket_file [network_name]
	rancher: (none)
EOF
	exit 1
fi

if [ -z "$FRONTIER_USER" ]; then
	export FRONTIER_USER=`cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1`
	echo "FRONTIER_USER not set in env, generated value: $FRONTIER_USER"
fi

if [ -z "$FRONTIER_PASS" ]; then
	export FRONTIER_PASS=`cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1`
	echo "FRONTIER_PASS not set in env, generated value: $FRONTIER_PASS"
fi

set -ueo pipefail

export script_dir="`dirname "$0"`"
export email=$1
export data_src=$2
shift 2

error()
{
	echo "ERROR: $@" 1>&2
	exit 1
}

warn()
{
	echo "WARNING: $@" 1>&2
}

# Overwrite the plaintext password in-memory
export FRONTIER_PASS=`/caddy hash-password --plaintext "$FRONTIER_PASS"`
if [ -z "$FRONTIER_PASS" ]; then
	error "FRONTIER_PASS is not set"
fi

case $data_src in
"docker-socket")
	if [ $# -lt 1 ]; then
		error "provide the socket file"
	fi

	socket_file=$1

	if [ $# -lt 2 ]; then
		warn "no network name provided, defaulting to 'bridge'"
		network_name="bridge"
	else
		network_name=$2
	fi

	proxy=/tmp/docker-proxy.sock
	rm -f "$proxy"
	socat "UNIX-CONNECT:$socket_file" "UNIX-LISTEN:$proxy,fork" &
	proxy_pid=$!
	while [ ! -e "$proxy" ]; do :; done
	chmod 777 "$proxy"

	export socket_file="$proxy"
	export network_name
	;;

"rancher")
	;;

*)
	error "unrecognized data source - $data_src"
esac

set +e
sudo -Eu nobody "$script_dir/daemon.sh"
daemon_exit=$!
set -e

if [ $data_src = "docker-socket" ]; then
	kill $proxy_pid
fi

exit $daemon_exit
