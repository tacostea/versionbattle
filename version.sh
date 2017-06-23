#!/bin/bash

function get_version() {
  DOMAIN=$1
  LINK="https://$DOMAIN/api/v1/instance"
  VER_RAW=$(curl -m 10 -s $LINK | jq -r '.version')
  VER=$(echo $VER_RAW | sed -r 's/.*>([0-9\.]+).*/\1/' | cut -c-5)
  if [ -n "$VER" ]; then
    echo "$VER $DOMAIN"
  fi
}

export -f get_version

if [ -f instances.list ]; then
  xargs -n1 -P0 -I % bash -c "get_version $INSTANCE %" < instances.list > results.list
else
  curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > .instances.list
  xargs -n1 -P0 -I % bash -c "get_version $INSTANCE %" < .instances.list
  rm -f .instances.list
fi
