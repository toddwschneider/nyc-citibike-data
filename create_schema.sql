CREATE EXTENSION postgis;

CREATE TABLE trips_raw (
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id integer,
  start_station_name varchar,
  start_station_latitude numeric,
  start_station_longitude numeric,
  end_station_id integer,
  end_station_name varchar,
  end_station_latitude numeric,
  end_station_longitude numeric,
  bike_id integer,
  user_type varchar,
  birth_year varchar,
  gender varchar
);

CREATE TABLE trips (
  id serial primary key,
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id integer,
  end_station_id integer,
  bike_id integer,
  user_type varchar,
  birth_year integer,
  gender integer
);

CREATE TABLE stations (
  id integer primary key,
  name varchar,
  latitude numeric,
  longitude numeric,
  nyct2010_gid integer,
  boroname varchar,
  ntacode varchar,
  ntaname varchar
);

SELECT AddGeometryColumn('stations', 'geom', 4326, 'POINT', 2);
CREATE INDEX idx_stations_on_geom ON stations USING gist (geom);

CREATE VIEW trips_and_stations AS (
  SELECT
    t.*,
    ss.name AS start_station_name,
    ss.latitude AS start_station_latitude,
    ss.longitude AS start_station_longitude,
    ss.nyct2010_gid AS start_nyct2010_gid,
    ss.boroname AS start_boroname,
    ss.ntacode AS start_ntacode,
    ss.ntaname AS start_ntaname,
    es.name AS end_station_name,
    es.latitude AS end_station_latitude,
    es.longitude AS end_station_longitude,
    es.nyct2010_gid AS end_nyct2010_gid,
    es.boroname AS end_boroname,
    es.ntacode AS end_ntacode,
    es.ntaname AS end_ntaname
  FROM trips t
    INNER JOIN stations ss ON t.start_station_id = ss.id
    INNER JOIN stations es ON t.end_station_id = es.id
);

CREATE TABLE directions (
  start_station_id integer,
  end_station_id integer,
  directions jsonb
);

CREATE UNIQUE INDEX idx_directions_on_stations ON directions (start_station_id, end_station_id);

CREATE TABLE central_park_weather_observations_raw (
  station_id varchar,
  station_name varchar,
  date date,
  precipitation_tenths_of_mm numeric,
  snow_depth_mm numeric,
  snowfall_mm numeric,
  max_temperature_tenths_degrees_celsius numeric,
  min_temperature_tenths_degrees_celsius numeric,
  average_wind_speed_tenths_of_meters_per_second numeric
);

CREATE INDEX index_weather_observations ON central_park_weather_observations_raw (date);

CREATE VIEW central_park_weather_observations AS
SELECT
  date,
  precipitation_tenths_of_mm / (100 * 2.54) AS precipitation,
  NULLIF(snow_depth_mm, -9999) / (10 * 2.54) AS snow_depth,
  NULLIF(snowfall_mm, -9999) / (10 * 2.54) AS snowfall,
  max_temperature_tenths_degrees_celsius * 9 / 50 + 32 AS max_temperature,
  min_temperature_tenths_degrees_celsius * 9 / 50 + 32 AS min_temperature,
  CASE
    WHEN average_wind_speed_tenths_of_meters_per_second >= 0
    THEN average_wind_speed_tenths_of_meters_per_second / 10 * (100 * 60 * 60) / (2.54 * 12 * 5280)
  END AS average_wind_speed
FROM central_park_weather_observations_raw;
