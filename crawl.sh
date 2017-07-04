#!/bin/bash

## CONFIG
# MAX NUMBER OF PROCESSES FOR PARALLEL PROCESSING
PROC=5

alias db="sudo -u postgres psql 1>/dev/null 2>/dev/null -U postgres -d instances -c "

function scrape() {
  DOMAIN=$1
  LINK="https://$DOMAIN/about"
  RESULT=$(curl -m 15 -k $LINK 2>/dev/null | xmllint --html --xpath "//div/div[1]/div[2]/" - 2>/dev/null | sed -e 's/<[^>]*>//g')
  if [ "$RESULT" == "" ];then
    REG="TRUE"
  else
    REG="FALSE"
  fi

  LINK="https://$DOMAIN/about/more"
  RESULT=$(curl -m 15 -k $LINK 2>/dev/null)
  USERS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[1]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//')
  STATUSES=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[2]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//')
  CONNS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[3]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//')

  echo "$DOMAIN, $USERS, $STATUSES, $CONNS, $REG" >> "scrape.txt"
}

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
    db "UPDATE list SET status = TRUE WHERE uri = '$DOMAIN'"
    scrape $DOMAIN
    echo "$DOMAIN, $TIME" >> time.txt
  else
    # それ以外の場合はレスポンスコードを http_error.txt に追加してDBに反映
    # ちなみに 000 => タイムアウト?
    db "UPDATE list SET delay = NULL, status = FALSE WHERE uri = '$DOMAIN'"
    echo "$DOMAIN, $STATUS" >> http_error.txt
  fi
}

echo -n > version.txt
echo -n > time.txt
echo -n > http_error.txt
echo -n > scrape.txt

export -f crawl
export -f scrape

if [ -f instances.list ]; then
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < instances.list
else
  curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > .instances.list
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < .instances.list
  rm -f .instances.list
fi

