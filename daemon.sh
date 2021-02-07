#!/bin/sh

set -ueo pipefail

config()
{
	json="$1"

	ip=`echo "$json" | jq -r '.ip'`
	port=`echo "$json" | jq -r '.port'`
	domains=`echo "$json" | jq -r '.domains'`
	if [ "$ip" = "null" ]; then
		echo "ERROR: duplicate domain specified for $domains" 1>&2
		return
	fi

	if echo "$json" | jq -er '.tags' > /dev/null; then
		tags=`echo "$json" | jq -r '.tags'`
	else
		tags=""
	fi

	if echo $tags | grep -q '\bredir2www\b'; then
		baredomains="$domains"
		if echo $baredomains | grep -q 'www\.'; then
			echo "ERROR: www domain specification not supported when tag redir2www is specified: $baredomains" 1>&2
			return
		fi

		# prefix all domains with www.
		domains=`echo $domains | sed 's/^/www./;s/, /, www./g'`
	fi

	cat <<EOF
$domains {
  encode gzip
  reverse_proxy * $ip:$port
EOF

	if echo $tags | grep -q '\blogin\b'; then
		cat <<EOF

  basicauth {
    $FRONTIER_USER $FRONTIER_PASS
  }
EOF
	fi

	echo '}'
	echo

	if echo $tags | grep -q '\bredir2www\b'; then
		echo "$baredomains" | tr ', ' '\n' | grep '[a-z]' | while read baredomain; do
		cat <<EOF
$baredomain {
  redir https://www.$baredomain
}

EOF
		done
	fi
}

get_config_from_docker_socket()
{
	curl -s --unix-socket "$socket_file" --header 'Accept: application/json' \
		'http://localhost/containers/json?filters=\{"status":\["running"\],"label":\["frontier.domains"\]\}' | \
		jq -c '.[] | select(.Labels | has("frontier.domains") and has("frontier.port")) | { "ip": .NetworkSettings.Networks.'$network_name'.IPAddress, "port": .Labels["frontier.port"], "domains": .Labels["frontier.domains"], "tags": .Labels["frontier.tags"] }' | \
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
	cat <<GLOBAL_CFG
{
  http_port 80
  https_port 443
  email $email

  servers {
    protocol {
      strict_sni_host
    }
  }

  storage file_system {
    root /state
  }
}

GLOBAL_CFG
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

current_cfg="`get_config`"
echo "$current_cfg" > Caddyfile

export HOME=/tmp
/caddy run &
pid=$!

while :; do
	ps -o pid | grep -q "^ *$pid$" || break

	next_cfg="`get_config`"
	if [ ! "$current_cfg" = "$next_cfg" ]; then
		current_cfg="$next_cfg"

		echo "Reloading with new config:"
		echo "$current_cfg"

		echo "$current_cfg" > Caddyfile

		/caddy reload
	fi

	sleep 10
done

wait $pid
caddy_exit=$?
echo "Caddy exited with code $caddy_exit"

exit $caddy_exit
