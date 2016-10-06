#!/bin/bash
## This report is designed to ping all the things in the list provided.

#### Variables
# Date
NOW=$(date +"%Y%m%d%H%M%S")
# Report Folder (This is the folder the report uses to keep track of hosts.)
HERE=`pwd`
mkdir -p $HERE/reports

#### CHECK IF HOSTS ARE UP

cat $1 | while read line ;

do

        count=$( ping -c 1 $line | grep icmp* | grep -v "Unreachable" | wc -l )

        if [ $count -eq 0 ]
                then
                        echo "1 $line is DOWN" >> $HERE/reports/$NOW.txt
                else
                        echo "0 $line is UP" >> $HERE/reports/$NOW.txt
                fi
done
