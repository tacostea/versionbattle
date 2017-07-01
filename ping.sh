#!/bin/bash

 echo "" > time.txt
 echo "" > http_error.txt
 echo "" > ping_error.txt

for DOMAIN in $(cat instances.list.org); do
  if ping -c 3 -t 15 $DOMAIN > /dev/null; then
    RESULT=$(curl -m 5 -kL $DOMAIN -o /dev/null -w "%{time_total} %{http_code}" 2> /dev/null)
#    RESULT=$(httping -c 3 -s https://$DOMAIN/api/v1/instance)
#    TIME=$(echo -e $RESULT | tail -n1 | sed -r 's/.*([0-9]+.[0-9])\/([0-9]+.[0-9])\/([0-9]+.[0-9] ms)/\2/')
#    STATUS=$(echo -e $RESULT |head -n3| tail -n1)

#    if echo $RESULT | grep " 3 ok," > /dev/null; then

    TIME=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\1/')
    STATUS=$(echo $RESULT | sed -r 's/([0-9]+\.[0-9]+) ([0-9]{1,3})/\2/')
    
#    echo "$DOMAIN, STATUS:$STATUS, TIME:$TIME"
    if [ "$STATUS" == "200" ]; then
      echo "$DOMAIN, $TIME" >> time.txt
    else
      echo "$DOMAIN, $STATUS" >> http_error.txt
    fi
  else
#    echo "ping timeout"
    echo "$DOMAIN" >> ping_error.txt
    continue
  fi
done
