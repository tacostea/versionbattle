#!/bin/bash
P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{print $1/$3*100;}')
while [ "$(echo "$P < 100"|bc)" -eq 1 ]; do 
  P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{print $1/$3*100;}')
  echo -en "$P\r"
  sleep 1
done
sh ~/push.sh "done" "curl list done"
