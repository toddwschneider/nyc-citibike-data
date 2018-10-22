#!/bin/bash

createdb nyc-citibike-data

psql nyc-citibike-data -f create_schema.sql

shp2pgsql -s 2263:4326 nyct2010_15b/nyct2010.shp | psql -d nyc-citibike-data
psql nyc-citibike-data -c "CREATE INDEX index_nyct_on_geom ON nyct2010 USING gist (geom);"
psql nyc-citibike-data -c "VACUUM ANALYZE nyct2010;"

shp2pgsql -s 2263:4326 taxi_zones/taxi_zones.shp | psql -d nyc-citibike-data
psql nyc-citibike-data -c "CREATE INDEX index_taxi_zones_on_geom ON taxi_zones USING gist (geom);"
psql nyc-citibike-data -c "CREATE INDEX index_taxi_zones_on_locationid ON taxi_zones (locationid);"
psql nyc-citibike-data -c "VACUUM ANALYZE taxi_zones;"

weather_schema="station_id, station_name, date, average_wind_speed, precipitation, snowfall, snow_depth, max_temperature, min_temperature"
cat data/central_park_weather.csv | psql nyc-citibike-data -c "COPY central_park_weather_observations (${weather_schema}) FROM stdin WITH CSV HEADER;"
psql nyc-citibike-data -c "UPDATE central_park_weather_observations SET average_wind_speed = NULL WHERE average_wind_speed = -9999;"
