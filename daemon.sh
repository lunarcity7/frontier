#!/bin/sh

set -ueo pipefail

config()
{
	json="$1"

	ip=`echo "$json" | jq -r '.ip'`
	port=`echo "$json" | jq -r '.port'`
	domains=`echo "$json" | jq -r '.domains'`

	if echo "$json" | jq -er '.tags' > /dev/null; then
		tags=`echo "$json" | jq -r '.tags'`
	else
		tags=""
	fi

	cat <<EOF
$domains {
	gzip

	proxy / $ip:$port {
		transparent
		websocket
	}
EOF

	if echo $tags | grep -q '\blogin\b'; then
		cat <<EOF

	jwt {
		path /
		except /login
		redirect /login
	}

	login {
		simple $FRONTIER_USER=$FRONTIER_PASS
	}
EOF
	fi

	echo '}'
}

get_config_from_docker_socket()
{
	curl -s --unix-socket "$socket_file" --header 'Accept: application/json' \
		'http://localhost/containers/json?filters=\{"status":\["running"\],"label":\["frontier.domains"\]\}' | \
		jq -c '.[] | select(.Labels | has("frontier.domains") and has("frontier.port")) | { "ip": .NetworkSettings.Networks.bridge.IPAddress, "port": .Labels["frontier.port"], "domains": .Labels["frontier.domains"], "tags": .Labels["frontier.tags"] }' | \
		while read json; do
			config "$json"
		done
}

get_config_from_rancher()
{
	curl -s --header 'Accept: application/json' http://rancher-metadata/2016-07-29/services | \
		jq -r '.[].containers[]? | select(.labels | has("frontier.domains") and has("frontier.port")) | { "ip": .ips[0], "port": .labels["frontier.port"], "domains": .labels["frontier.domains"], "tags": .labels["frontier.tags"] }' | \
		while read l; do
			config "$json"
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
