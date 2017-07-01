#!/bin/bash

echo -n > time.txt
echo -n > http_error.txt

for DOMAIN in $(cat instances.list); do
  RESULT=$(curl -m 10 -kL https://$DOMAIN/api/v1/instance -o /dev/null -w "%{time_total} %{http_code}" 2> /dev/null)

  TIME=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\1/')
  STATUS=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\2/')
    
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
done
