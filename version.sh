#!/bin/bash

#=========CONFIG=========

FILE="instances.txt"

#========/CONFIG=========

# Get instance name list and save
curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > $FILE

for INSTANCE in `<$FILE`; do
  LINK="https://$INSTANCE/about/more"
  VER=`curl -s $LINK | grep -E "<strong>[0-9]\.[0-9]\.[0-9]</strong>" | sed -r 's/.*>([0-9\.]+).*/\1/'`
  if [ -n "$VER" ]; then
    echo "$VER $INSTANCE"
  fi
done
