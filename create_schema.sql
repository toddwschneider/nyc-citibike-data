CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE trips_raw (
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id text,
  start_station_name text,
  start_station_latitude numeric,
  start_station_longitude numeric,
  end_station_id text,
  end_station_name text,
  end_station_latitude numeric,
  end_station_longitude numeric,
  bike_id integer,
  user_type text,
  birth_year text,
  gender text,
  ride_id text,
  rideable_type text
);

CREATE TABLE trips (
  id serial primary key,
  trip_duration numeric,
  start_time timestamp without time zone,
  stop_time timestamp without time zone,
  start_station_id text,
  end_station_id text,
  bike_id integer,
  user_type text,
  birth_year integer,
  gender integer,
  ride_id text,
  rideable_type text,
  start_latitude numeric,
  start_longitude numeric,
  end_latitude numeric,
  end_longitude numeric,
  start_station_name text,
  end_station_name text
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
  gender integer,
  ride_id text,
  rideable_type text
);

CREATE TABLE stations (
  normalized_id text primary key,
  name text not null,
  latitude numeric,
  longitude numeric,
  data_source text,
  nyct2010_gid integer,
  boroname text,
  ntacode text,
  ntaname text,
  taxi_zone_gid integer,
  taxi_zone_name text
);

SELECT AddGeometryColumn('stations', 'geom', 4326, 'POINT', 2);
CREATE INDEX ON stations USING gist (geom);

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

CREATE OR REPLACE FUNCTION normalize_station_id(station_id text, start_time timestamp without time zone) RETURNS text
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  RETURN
    CASE
      WHEN start_time >= '2021-02-01'
      THEN regexp_replace(station_id, '^(\d+\.\d)$', '\1' || '0')
      ELSE regexp_replace(station_id, '\.00?$', '')
    END;
