#!/bin/bash

urlencode() {
	hexdump -v -e '1/1 "%02x"' |\
		sed 's/../%&/g'
}


URIS=(
	"https://sponsor.ajay.app"
	"https://sponsorblock.kavin.rocks"
	"https://sponsorblock.gleesh.net"
	"https://sponsorblock.2255.me"
	"https://sponsorblock.hostux.net"
)


if [ ${#} -lt 1 ]; then
	echo "usage: ${0} <videoID>" >&2
	exit 1
fi
vid="${1}"

hsh="$(echo -n "${vid}" |sha256sum |head -c 4)"
cats="$(echo -n '["sponsor","selfpromo","interaction","intro","outro"]' |urlencode)"

for uri in "${URIS[@]}"; do
	echo "=============== trying ${uri}..." >&2
	curl \
		-f \
		-m 5 \
		"${uri}/api/skipSegments/${hsh}?categories=${cats}" |\
		jq --tab ".[] |select(.videoID == \"${vid}\")"
done

