#!/bin/bash

if [ $# -lt 1 ];then exit 1;fi

cat $1 | while read DOMAIN; do
  host ${DOMAIN} | awk '/NX/{nx=1} /IPv6/{v6=1};/has address/{v4=1} END{if(v4&&!v6){printf "v4   "} else if(!v4&&v6){printf "v6   "} else if(v4&&v6){printf "v4+v6"} else if(nx){printf "nx   "} else{printf "inv. "}}'
  echo " $DOMAIN"
done
