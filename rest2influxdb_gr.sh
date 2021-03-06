#!/bin/bash
# This script lists all items in a group of items to read their values via REST and imports the data to influxdb
# Only compatible with openhab 2.1 (and newer)
# usage: rest2influxdb_gr.sh <groupname>

source ./config.cfg

groupname="$1"

if [ -z $groupname ]
then
  echo "Please define Group!"
  exit 0
fi
# convert historical times to unix timestamps,
tenyearsago=`date +"%Y-%m-%dT%H:%M:%S" --date="10 years ago"`
oneyearago=`date +"%Y-%m-%dT%H:%M:%S" --date="-12 months 28 days ago"`
onemonthago=`date +"%Y-%m-%dT%H:%M:%S" --date="29 days ago"`
oneweekago=`date +"%Y-%m-%dT%H:%M:%S" --date="-6 days -23 hours 59 minutes ago"`
onedayago=`date +"%Y-%m-%dT%H:%M:%S" --date="-23 hours 59 minutes ago"`
eighthoursago=`date +"%Y-%m-%dT%H:%M:%S" --date="-7 hours 59 minutes ago"`


# print timestamps
echo ""
echo "### timestamps"
echo "10y:  $tenyearsago"
echo "1y:   $oneyearago"
echo "1m:   $onemonthago"
echo "1w:   $oneweekago"
echo "1d:   $onedayago"
echo "8h:   $eighthoursago"

listurl="http://$openhabserver:$openhabport/rest/items/$groupname"
curl -X GET --header "Accept: application/json" "$listurl"   > list.xml
cat list.xml      | jq -r '.members[].name'  > list.txt
cat list.txt | while read LINE
do
itemname=$LINE
echo "item: $itemname"


resturl="http://$openhabserver:$openhabport/rest/persistence/items/$itemname?serviceId=$serviceid"

# get values and write to different files
curl -X GET --header "Accept: application/json" "$resturl&starttime=${tenyearsago}&endtime=${oneyearago}"  > ${itemname}_10y.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneyearago}&endtime=${onemonthago}"  > ${itemname}_1y.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${onemonthago}&endtime=${oneweekago}"  > ${itemname}_1m.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneweekago}&endtime=${onwdayago}"    > ${itemname}_1w.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${onedayago}&endtime=${eighthoursago}" > ${itemname}_1d.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${eighthoursago}"                      > ${itemname}_8h.xml

# combine files
cat ${itemname}_10y.xml ${itemname}_1y.xml ${itemname}_1m.xml ${itemname}_1w.xml ${itemname}_1d.xml ${itemname}_8h.xml > ${itemname}.xml
# convert data to line protocol file
cat ${itemname}.xml \
     | sed 's/}/\n/g' \
     | sed 's/data/\n/g' \
     | grep -e "time.*state"\
     | tr -d ',:[{"' \
     | sed 's/time/ /g;s/state/ /g' \
     | awk -v item="$itemname" '{print item " value=" $2 " " $1 "000000"}' \
     | sed 's/value=ON/value=1/g;s/value=OFF/value=0/g' \
     > ${itemname}.txt

values=`wc -l ${itemname}.txt | cut -d " " -f 1`
echo ""
echo "### found values: $values"


# split file in smaller parts to make it easier for influxdb

linestart=1
linestop=$importsize

until [ $linestart -gt $values ]; do
  echo ""
  echo "### Line from $linestart to $linestop"
  linestart=$((linestart+importsize))
  linestop=$((linestop+importsize))
  cat ${itemname}.txt | sed -n "${linestart},${linestop}p" > ${itemname}_${linestart}.txt

  # print import command for debug
#  echo "curl -i -XPOST -u $influxuser:$influxpw 'http://$influxserver:$influxport/write?db=$influxdatbase' --data-binary @${itemname}_${linestart}.txt"
  # execute import command
  curl -i -XPOST -u $influxuser:$influxpw "http://$influxserver:$influxport/write?db=$influxdatbase" --data-binary @${itemname}_${linestart}.txt

  echo "Sleep for $sleeptime seconds to let InfluxDB process the data..."
  sleep $sleeptime
done

echo ""
echo "### delete temporary files"
rm ${itemname}*
done
exit 0
