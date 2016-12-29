#!/bin/bash

DB=1
KEY=coin0

for i in `seq 1 100`
do
	redis-cli -n $DB LPUSH $KEY address$RANDOM-$i
done
