#!/bin/bash

# Get instance name list and save
INSTANCELIST=$(curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name)

for INSTANCE in $INSTANCELIST; do
  LINK="https://$INSTANCE/about/more"
  VER=`curl -s $LINK | grep -E "<strong>[0-9]\.[0-9]\.[0-9]</strong>" | sed -r 's/.*>([0-9\.]+).*/\1/'`
  if [ -n "$VER" ]; then
    echo "$VER $INSTANCE"
  fi
done
