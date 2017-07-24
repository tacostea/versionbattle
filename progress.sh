#!/bin/bash
finalize(){
  #clear
  echo -e "\033[3B"
  exit 1
}

set -e
trap "finalize" ERR 2

P=$(echo $(wc -l $1 | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{print $1/$3*100;}')
while [ $(echo "$P < 100"|bc) -eq 1 ]; do 
  P=$(echo $(wc -l $1 | tail -n1) $(wc -l instances.list| tr -d [:alpha:][:punct:][:blank:]) | awk '{printf "%2.2f", $1/$3*100;}')
  echo -e "\n$P%                     "
  wc -l $1
  wc -l instances.list
  echo -e "\033[5A\r"
  sleep 1
done
echo -e "\033[3B"
