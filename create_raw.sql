CREATE TABLE trips_raw (
  trip_duration numeric,
  start_time varchar,   -- modified to timestamp in populate_trips_from_raw.sql
  stop_time varchar,    -- modified to timestamp in populate_trips_from_raw.sql
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
