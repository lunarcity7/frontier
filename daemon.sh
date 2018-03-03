#!/bin/sh

set -ueo pipefail

config()
{
	ip_and_port="$1"
	domains="$2"

	cat <<EOF
$domains {
	gzip

	proxy / $ip_and_port {
		transparent
		websocket
	}
}
EOF
}

get_config_from_docker_socket()
{
	curl -s --unix-socket "$socket_file" --header 'Accept: application/json' \
		'http://localhost/containers/json?filters=\{"status":\["running"\],"label":\["frontier.domains"\]\}' | \
		jq -r '.[] | select(.Labels | has("frontier.domains") and has("frontier.port")) | .NetworkSettings.Networks.bridge.IPAddress + ":" + .Labels["frontier.port"] + " " + .Labels["frontier.domains"]' | \
		while read l; do
			ip_and_port=`echo $l | sed 's/ .*//'`
			domains=`echo $l | sed 's/[^ ]* //'`

			config "$ip_and_port" "$domains"
		done
}

get_config_from_rancher()
{
	curl -s --header 'Accept: application/json' http://$metadata/2016-07-29/services | \
		jq -r '.[].containers[]? | select(.labels | has("frontier.domains") and has("frontier.port")) | .ips[0] + ":" + .labels["frontier.port"] + " " + .labels["frontier.domains"]' | \
		while read l; do
			ip_and_port=`echo $l | sed 's/ .*//'`
			domains=`echo $l | sed 's/[^ ]* //'`

			config "$ip_and_port" "$domains"
		done
}

get_config()
{
	case $data_src in
	"docker-socket")
		get_config_from_docker_socket
		;;
	"rancher")
		get_config_from_rancher
		;;
	*)
		error "unrecognized data source - $data_src"
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
