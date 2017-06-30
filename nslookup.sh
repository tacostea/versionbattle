#!/bin/bash

for NAME in $(cat instances.list); do
  nslookup $NAME | grep -i "can't"
done
