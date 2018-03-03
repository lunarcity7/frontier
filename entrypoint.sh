#!/bin/sh

set -ueo pipefail

if [ $# -lt 2 ]; then
	cat <<EOF 1>&2
USAGE: $0 letsencrypt_email data_src <data_src_args...>
    where data_src can be one of: docker-socket, rancher

    NB. rancher source is buggy when metadata server changes

    params for data sources:
        docker-socket: socket_file
        rancher: metadata_server_host_or_ip
EOF
	exit 1
fi

export script_dir="`dirname "$0"`"

export email=$1
export data_src=$2
shift 2

error()
{
	echo "ERROR: $@" 1>&2
	exit 1
}

case $data_src in
"docker-socket")
	if [ $# -ne 1 ]; then
		error "provide the socket file"
	fi

	socket_file=$1

	proxy=/tmp/docker-proxy.sock
	socat "UNIX-CONNECT:$socket_file" "UNIX-LISTEN:$proxy,fork" &
	proxy_pid=$!
	while [ ! -e "$proxy" ]; do :; done
	chmod 777 "$proxy"

	export socket_file="$proxy"
	;;

"rancher")
	if [ $# -ne 1 ]; then
		error "provide the host or IP for the metadata server"
	fi

	export metadata=$1
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
