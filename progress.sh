#!/bin/bash
P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{print $1/$3*50;}')
while [ $(echo "$P < 100"|bc) -eq 1 ]; do 
  P=$(echo $(wc -l *.txt | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{printf "%2.2f", $1/$3*50;}')
  echo "$P%"
  wc -l *.txt
  echo -e "\033[6A\r"
  sleep 1
done
echo -e "\033[3B"
