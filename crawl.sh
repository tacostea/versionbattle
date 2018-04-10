#!/bin/bash

## CONFIG
readonly LOCKFILE="crawl.lock"
# MAX NUMBER OF PROCESSES FOR PARALLEL PROCESSING
PROC=10

(
flock -w 15 -x 200 || exit 1

export RESULTFILE="result.tmp"
export SCRAPEFILE="scrape.tmp"
alias db="sudo -u postgres psql 1>/dev/null 2>/dev/null -U postgres -d instances -c "

function scrape() {
  DOMAIN=$1
  LINK="https://$DOMAIN/about"
  RESULT=$(curl -m 5 -k $LINK 2>/dev/null | xmllint --html --xpath "//div/div[1]/div[2]/" - 2>/dev/null | sed -e 's/<[^>]*>//g')
  if [ "$RESULT" == "" ];then
    REG="TRUE"
  else
    REG="FALSE"
  fi

  LINK="https://$DOMAIN/about/more"
  API_LINK="https://$DOMAIN/api/v1/instance"

  RESULT=$(curl -m 5 -k $LINK 2>/dev/null)
  API_RESULT=$(curl -m 5 -kL $API_LINK -w "\ntime=%{time_total} code=%{http_code}" 2>/dev/null)
  
  INSTANCE_FULL_VER=$(echo $API_RESULT | jq -r '.version' 2>/dev/null)
  if [[ $INSTANCE_FULL_VER =~ ^([0-9]+\.[0-9]+)\.([0-9]+) ]]; then INSTANCE_SIMPLE_VER=${BASH_REMATCH[1]}; fi
  
  if [[ $INSTANCE_SIMPLE_VER < 1.5 ]] ; then
    USERS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[1]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
    STATUSES=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[2]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
    CONNS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div/div[1]/div[2]/div[3]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
  #else if api available 
  else
    USERS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div[2]/div/div[1]/div[1]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
    STATUSES=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div[2]/div/div[1]/div[2]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
    CONNS=$(echo $RESULT | xmllint --html --xpath "/html/body/div/div[2]/div/div[1]/div[3]/strong" - 2>/dev/null | sed -e 's/<[^>]*>//g' | sed -e 's/[, ]//g')
  fi

  echo "$DOMAIN, $USERS, $STATUSES, $CONNS, $REG" >> ${SCRAPEFILE}
}
export -f scrape

function crawl() {
  local BUF=""
  DOMAIN=$1
  if [ "$DOMAIN" == "" ]; then return 1; fi
  LINK="https://$DOMAIN/api/v1/instance"
  RESULT=$(curl -6 -m 5 -kL $LINK 2>/dev/null)
  CODE=$?
  VER=$(echo $RESULT | jq -r '.version' 2>/dev/null)
  TIME=$(echo "$(curl -6 -m 5 -o /dev/null --silent --head -w "%{time_total}\n" $LINK -o /dev/null) * 1000" | bc)
  STATUS=$(curl -6 -m 5 -o /dev/null --silent --head -w "%{http_code}\n" $LINK -o /dev/null)
  
  # pass v6
  if [ "$STATUS" == "200" ]; then
    STATUS=$(curl -4 -m 5 -o /dev/null --silent --head -w "%{http_code}\n" $LINK -o /dev/null)
    scrape $DOMAIN
    # pass v4/v6
    if [ "$STATUS" == "200" ]; then
      if [[ ! "$VER" =~ [0-9]+(\.[0-9]+){2} ]]; then
        BUF="$DOMAIN, Up, 0.0.0, $TIME, v4/v6"
      else
        BUF="$DOMAIN, Up, $VER, $TIME, v4/v6"
      fi
    # pass v6 only
    else
      if [[ ! "$VER" =~ [0-9]+(\.[0-9]+){2} ]]; then
        BUF="$DOMAIN, Up, 0.0.0, $TIME, v6"
      else
        BUF="$DOMAIN, Up, $VER, $TIME, v6"
      fi
    fi
  # cannot pass v6
  else
    RESULT=$(curl -4 -m 5 -kL $LINK 2>/dev/null)
    VER=$(echo $RESULT | jq -r '.version' 2>/dev/null)
    TIME=$(echo "$(curl -4 -m 5 -o /dev/null --silent --head -w "%{time_total}\n" $LINK -o /dev/null) * 1000" | bc)
    STATUS=$(curl -4 -m 5 -o /dev/null --silent --head -w "%{http_code}\n" $LINK -o /dev/null)
    # pass v4 only
    if [ "$STATUS" == "200" ]; then
      scrape $DOMAIN
      if [[ ! "$VER" =~ [0-9]+(\.[0-9]+){2} ]]; then
        if [ "$CODE" != "6" ]; then
          BUF="$DOMAIN, Up, 0.0.0, $TIME, v4/ex"
        else
          BUF="$DOMAIN, Up, 0.0.0, $TIME, v4"
        fi
      else
        if [ "$CODE" != "6" ]; then
          BUF="$DOMAIN, Up, $VER, $TIME, v4/ex"
        else
          BUF="$DOMAIN, Up, $VER, $TIME, v4"
        fi  
      fi
    # cannot connect
    else
      if [[ "$STATUS" =~ [0-9]{3} ]]; then
        BUF="$DOMAIN, Down, $STATUS"
      fi
    fi
  fi # cannot pass v6 END
  
  echo $BUF >> ${RESULTFILE}
}
export -f crawl

echo -n > $RESULTFILE
echo -n > $SCRAPEFILE

if [ -f instances.list ]; then
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < instances.list
else
  curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > .instances.list
  xargs -n1 -P$PROC -I % bash -c "crawl $INSTANCE %" < .instances.list
  rm -f .instances.list
fi

if [ -e result.txt ];then
  cat result.txt >> log/result.txt && rm -f result.txt
fi
if [ -e scrape.txt ];then
  cat scrape.txt >> log/scrape.txt && rm -f scrape.txt
fi

sort -uk1,1 $RESULTFILE -o result.txt
sort -uk1,1 $SCRAPEFILE -o scrape.txt

) 200>$LOCKFILE
