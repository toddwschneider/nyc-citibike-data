#!/bin/bash

export GLOBIGNORE="data/central_park_weather.csv":"data/daily_citi_bike_trip_counts_and_weather.csv"

for filename in data/*.csv; do
  psql nyc-citibike-data -f create_raw.sql
  echo "`date`: beginning load for ${filename}"

  sed $'s/\"//g; s/\\\N//' "${filename}" | psql nyc-citibike-data -c \
      "COPY trips_raw FROM stdin WITH (FORMAT CSV, HEADER TRUE) ;"
  echo "`date`: finished raw load for ${filename}"

  psql nyc-citibike-data -f populate_trips_from_raw.sql
  echo "`date`: loaded trips for ${filename}"
done;
export GLOBIGNORE=

psql nyc-citibike-data -f create_indexes.sql
