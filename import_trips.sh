#!/bin/bash

for filename in data/20*.csv; do
  echo "`date`: beginning load for ${filename}"

  sed $'s/\\\N//' "${filename}" | psql nyc-citibike-data -c "SET datestyle = 'ISO, MDY'; COPY trips_raw FROM stdin CSV HEADER NULL 'NULL';"
  echo "`date`: finished raw load for ${filename}"

  psql nyc-citibike-data -f populate_trips_from_raw.sql
  echo "`date`: loaded trips for ${filename}"
done;

psql nyc-citibike-data -f create_indexes.sql
