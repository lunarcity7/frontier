#!/bin/sh

set -ue

if [ $# -le 2 ]; then
	echo "USAGE: $0 letsencrypt_email data_src <data_src_args...>" 1>&2
	echo "   where data_src can be one of: rancher" 1>&2
	echo "" 1>&2
	echo "   params for data sources:" 1>&2
	echo "       rancher: metadata_server_host_or_ip" 1>&2
	exit 1
fi

email=$1
data_src=$2
shift 2

case $data_src in
"rancher")
	if [ $# -ne 1 ]; then
		echo "Provide the host or IP for the metadata server" 1>&2
		exit 1
	fi

	metadata=$1
	;;
*)
	echo "ERROR: unrecognized data source - $data_src" 1>&2
	exit 1
esac

config()
{
	ip_and_port="$1"
	domains="$2"

	cat <<EOF
$domains {
	proxy / $ip_and_port {
		transparent
		websocket
		gzip
	}
}
EOF
}

get_config_from_rancher()
{
	curl -s --header 'Accept: application/json' http://$metadata/2016-07-29/services | \
		jq -r '.[].containers[] | select(.labels | has("trp.domains") and has("trp.port")) | .ips[0] + ":" + .labels["trp.port"] + " " + .labels["trp.domains"]' | \
		while read l; do
			ip_and_port=`echo $l | sed 's/ .*//'`
			domains=`echo $l | sed 's/[^ ]* //'`

			config "$ip_and_port" "$domains"
		done
}

get_config()
{
	case $data_src in
	"rancher")
		get_config_from_rancher
		;;
	*)
		echo "ERROR: unrecognized data source - $data_src" 1>&2
		exit 1
	esac
}

current_cfg="* {
    internal /
}"
echo "$current_cfg" > Caddyfile

caddy -agree -log stdout -http-port 80 -https-port 443 -email $email &
pid=$!

while :; do
	ps -o pid | grep -q "^ *$pid$" || break

	next_cfg="`get_config`"
	if [ ! "$current_cfg" = "$next_cfg" ]; then
		current_cfg="$next_cfg"
		echo "$current_cfg" > Caddyfile

		echo "Reloading with new config:"
		echo "$current_cfg"

		kill -USR1 $pid || break
	fi

	sleep 10
done

wait $pid
caddy_exit=$?
echo "Caddy exited with code $caddy_exit"

exit $caddy_exit
