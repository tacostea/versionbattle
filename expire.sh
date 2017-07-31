#!/bin/bash

chmod a+x ssl-exp.txt
echo -n > ssl-exp.txt

for DOMAIN in $(cat instances.list); do
  unset END
  unset CER
  CER=$(timeout 1s openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null )
  if [ "$CER" != "" ]; then 
    END=$(echo "$CER" | openssl x509 -enddate 2>/dev/null | sed -rn 's/^(notAfter=)(.*)$/\2/p')
    if [ "$END" != "" ]; then
      ENDF=$(date '+%F %T' -d "$END")
      echo "$ENDF $DOMAIN" >> ssl-exp.txt
    fi
  else
    echo $DOMAIN >> err.txt
  fi
done

echo "$(date '+%F %T') [=*=*=*=*= NOW =*=*=*=*=]" >> ssl-exp.txt
echo "$(date '+%F %T' -d +1day) [=*=*=*=*= 24H =*=*=*=*=]" >> ssl-exp.txt
echo "$(date '+%F %T' -d +1month) [=*=*=*=*= A MONTH =*=*=*=*=]" >> ssl-exp.txt

sort -k1 -k2 ssl-exp.txt -o ssl-exp.txt

sed -ie "1s/^/[ Updated : `date "+%F %T"` JST(UTC+9) ]\n/" ssl-exp.txt
