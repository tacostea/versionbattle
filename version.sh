#!/bin/bash

function get_version() {
  DOMAIN=$1
  LINK="https://$DOMAIN/api/v1/instance"
  VER_RAW=$(curl -m 5 -s $LINK | jq -r '.version' 2>/dev/null)
  VER=$(echo $VER_RAW | sed -r 's/.*>([0-9\.]+).*/\1/' | cut -c-5 2>/dev/null)
  if [[ ! "$VER" =~ [0-9]+(\.[0-9]+){2} ]]; then
    echo "$DOMAIN, ?.?.?"
  else
    echo "$DOMAIN, $VER"
  fi
}

export -f get_version

if [ -f instances.list ]; then
  mv results.list results.list.old
  xargs -n1 -P10 -I % bash -c "get_version $INSTANCE %" < instances.list >> results.list
  sort -u results.list -o results.list
  sed -i "1s/^/$(LANG=C date)\n/" results.list
else
  curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > .instances.list
  xargs -n1 -P5 -I % bash -c "get_version $INSTANCE %" < .instances.list
  rm -f .instances.list
fi

