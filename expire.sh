#!/bin/bash
echo -n > ssl-exp.txt
chmod a+x ssl-exp.txt

for DOMAIN in $(cat instances.list); do
  END=""
  END=$(timeout 2s openssl s_client -connect $DOMAIN:443 --servername $DOMAIN 2>&1 < /dev/null | openssl x509 -enddate 2>/dev/null | sed -rn 's/^(notAfter=)(.*)$/\2/p')
  if [ "$END" != "" ]; then
    END=$(date "+%F %T" -d "$END")
    echo "$END $DOMAIN" >> ssl-exp.txt
  fi
done
sort -k1 -k2 ssl-exp.txt -o ssl-exp.txt
sed -ie "1s/^/[`date "+%F %T"` (JST=UTC+9) updated]\n/" ssl-exp.txt
