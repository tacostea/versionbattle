#!/bin/bash
P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{print $1/$3*100;}')
while [ $(echo "$P < 100"|bc) -eq 1 ]; do 
  P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{printf "%2.2f", $1/$3*100;}')
  echo "$P%"
  wc -l *.txt
  echo -e "\033[5A\r"
  sleep 1
done
echo -e "\033[3B"
sh ~/push.sh "done" "ping.sh has been terminated." 1>/dev/null 2>/dev/null
echo
