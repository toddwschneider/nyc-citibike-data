#!/bin/bash

year_month_regex="([0-9]{4})-?([0-9]{2})"

schema_pre_202102="(trip_duration, start_time, stop_time, start_station_id, start_station_name, start_station_latitude, start_station_longitude, end_station_id, end_station_name, end_station_latitude, end_station_longitude, bike_id, user_type, birth_year, gender)"

schema_202102="(ride_id, rideable_type, start_time, stop_time, start_station_name, start_station_id, end_station_name, end_station_id, start_station_latitude, start_station_longitude, end_station_latitude, end_station_longitude, user_type)"

for filename in data/20*tripdata/*/*.csv; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}
  month=$((10#${BASH_REMATCH[2]}))

  if [ $year -lt 2021 ] || ([ $year -eq 2021 ] && [ $month -eq 1 ] ); then
    schema=$schema_pre_202102
  else
    schema=$schema_202102
  fi

  echo "`date`: beginning load for ${filename}"

  sed $'s/\\\N//' "${filename}" | psql nyc-citibike-data -c "SET datestyle = 'ISO, MDY'; COPY trips_raw ${schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"

  psql nyc-citibike-data -f populate_trips_from_raw.sql
  echo "`date`: loaded trips for ${filename}"
done;

for filename in data/2024*tripdata*.csv; do
  echo "`date`: beginning load for ${filename}"

  sed $'s/\\\N//' "${filename}" | psql nyc-citibike-data -c "SET datestyle = 'ISO, MDY'; COPY trips_raw ${schema_202102} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"

  psql nyc-citibike-data -f populate_trips_from_raw.sql
  echo "`date`: loaded trips for ${filename}"
done;

psql nyc-citibike-data -f create_indexes.sql

psql nyc-citibike-data -f add_calculated_stations_data.sql
psql nyc-citibike-data -f map_stations_to_geos.sql
