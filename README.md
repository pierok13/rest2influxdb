# Introduction

This script reads values for a defined item from openHAB via the REST interface.
The values are written to text files and converted to a specific format to import them in InfluxDB.
see: https://docs.influxdata.com/influxdb/v1.2/write_protocols/line_protocol_reference/

# Usage

Copy `config.cfg.example` to `config.cfg` and define your parameters like server name, user, password etc.

Start script
`./rest2influxdb.sh <Item_Name>`

Done.

# Processing groups
`./rest2influxdb_gr.sh <Group_Name>`


# (un)known Issues

* ** COMPATIBLE WITH openHAB 2.3**
* The timestamps cannot be calculated correctly on macOS
* RRD compresses data, so the further you go into the past the bigger gaps you get between two data points.  
see: https://github.com/openhab/openhab1-addons/wiki/rrd4j-persistence
* I am not sure if the defined timestamps are correct to read as much data as possible.
* 

