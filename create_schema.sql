CREATE EXTENSION postgis;

CREATE TABLE trips_raw (
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id integer,
  start_station_name text,
  start_station_latitude numeric,
  start_station_longitude numeric,
  end_station_id integer,
  end_station_name text,
  end_station_latitude numeric,
  end_station_longitude numeric,
  bike_id integer,
  user_type text,
  birth_year text,
  gender text
);

CREATE TABLE trips (
  id serial primary key,
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id integer,
  end_station_id integer,
  bike_id integer,
  user_type text,
  birth_year integer,
  gender integer
);

CREATE TABLE dockless_trips (
  id serial primary key,
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_latitude numeric,
  start_longitude numeric,
  end_latitude numeric,
  end_longitude numeric,
  bike_id integer,
  user_type text,
  birth_year integer,
  gender integer
);

CREATE TABLE stations (
  id serial primary key,
  external_id integer not null,
  name text,
  latitude numeric,
  longitude numeric,
  nyct2010_gid integer,
  boroname text,
  ntacode text,
  ntaname text,
  taxi_zone_gid integer,
  taxi_zone_name text
);

CREATE UNIQUE INDEX ON stations (external_id, latitude, longitude);

SELECT AddGeometryColumn('stations', 'geom', 4326, 'POINT', 2);
CREATE INDEX ON stations USING gist (geom);

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
    ss.taxi_zone_gid AS start_taxi_zone_gid,
    ss.taxi_zone_name AS start_taxi_zone_name,
    es.name AS end_station_name,
    es.latitude AS end_station_latitude,
    es.longitude AS end_station_longitude,
    es.nyct2010_gid AS end_nyct2010_gid,
    es.boroname AS end_boroname,
    es.ntacode AS end_ntacode,
    es.ntaname AS end_ntaname,
    es.taxi_zone_gid AS end_taxi_zone_gid,
    es.taxi_zone_name AS end_taxi_zone_name
  FROM trips t
    INNER JOIN stations ss ON t.start_station_id = ss.id
    INNER JOIN stations es ON t.end_station_id = es.id
);

CREATE TABLE central_park_weather_observations (
  station_id text,
  station_name text,
  date date primary key,
  precipitation numeric,
  snow_depth numeric,
  snowfall numeric,
  max_temperature numeric,
  min_temperature numeric,
  average_wind_speed numeric
);
