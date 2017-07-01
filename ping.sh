#!/bin/bash

echo "" > time.txt
echo "" > http_error.txt
echo "" > ping_error.txt

for DOMAIN in $(cat instances.list); do
  RESULT=$(curl -m 5 -kL https://$DOMAIN/api/v1/instance -o /dev/null -w "%{time_total} %{http_code}" 2> /dev/null)

  TIME=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\1/')
  STATUS=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\2/')
    
  if [ "$STATUS" == "200" ]; then
    # HTTP 202 OK の場合は time.txt に追加
    echo "$DOMAIN, $TIME" >> time.txt
  else
    # それ以外の場合はレスポンスコードを http_error.txt に追加
    echo "$DOMAIN, $STATUS" >> http_error.txt
  fi
done
