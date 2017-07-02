#!/bin/bash

## CONFIG
# MAX NUMBER OF PROCESSES FOR PARALLEL PROCESSING
PROC=5

function crawl() {
  DOMAIN=$1
  LINK="https://$DOMAIN/api/v1/instance"
  RESULT=$(curl -m 15 -k $LINK -w "\n%{time_total} %{http_code}" 2>/dev/null)
  
  VER_RAW=$(echo $RESULT | jq -r '.version' 2>/dev/null)
  VER=$(echo $VER_RAW | sed -r 's/.*>([0-9\.]+).*/\1/' | cut -c-5 2>/dev/null)
  if [[ ! "$VER" =~ [0-9]+(\.[0-9]+){2} ]]; then
    echo "$DOMAIN, ?.?.?" >> version.txt
  else
    echo "$DOMAIN, $VER" >> version.txt
  fi

  TIME=$(echo "$(echo $RESULT | sed -r 's/.*([0-9]+\.[0-9]+) ([0-9]{3}$)/\1/') * 1000" | bc)
  STATUS=$(echo $RESULT | sed -r 's/.*([0-9]+\.[0-9]+) ([0-9]{3})$/\2/')

  if [ "$STATUS" == "200" ]; then
    # HTTP 202 OK の場合は time.txt に追加
    sudo -u postgres psql -U postgres -d instances -c "UPDATE list SET status = TRUE WHERE uri = '$DOMAIN'" 1>/dev/null 2>/dev/null
    echo "$DOMAIN, $TIME" >> time.txt
  else
    # それ以外の場合はレスポンスコードを http_error.txt に追加してDBに反映
    # ちなみに 000 => タイムアウト?
    sudo -u postgres psql -U postgres -d instances -c "UPDATE list SET delay = NULL, status = FALSE WHERE uri = '$DOMAIN'" 1>/dev/null 2>/dev/null
    echo "$DOMAIN, $STATUS" >> http_error.txt
  fi
}

echo -n > version.txt
echo -n > time.txt
echo -n > http_error.txt

export -f crawl

if [ -f instances.list ]; then
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < instances.list
else
  curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > .instances.list
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < .instances.list
  rm -f .instances.list
fi

