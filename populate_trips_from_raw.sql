INSERT INTO trips
(
  trip_duration, start_time, stop_time, start_station_id, end_station_id,
  bike_id, user_type, birth_year, gender, ride_id, rideable_type,
  start_station_name, end_station_name, start_latitude, start_longitude,
  end_latitude, end_longitude
)
SELECT
  trip_duration,
  start_time,
  stop_time,
  normalize_station_id(start_station_id, start_time) AS start_station_id,
  normalize_station_id(end_station_id, start_time) AS end_station_id,
  bike_id,
  user_type,
  nullif(nullif(birth_year, ''), 'NULL')::numeric::int AS birth_year,
  nullif(nullif(gender, ''), 'NULL')::numeric::int AS gender,
  ride_id,
  rideable_type,
  start_station_name,
  end_station_name,
  nullif(start_station_latitude, 0) AS start_latitude,
  nullif(start_station_longitude, 0) AS start_longitude,
  nullif(end_station_latitude, 0) AS end_latitude,
  nullif(end_station_longitude, 0) AS end_longitude
FROM trips_raw
WHERE start_station_id IS NOT NULL
  AND end_station_id IS NOT NULL;

INSERT INTO dockless_trips
(
  trip_duration, start_time, stop_time, start_latitude, start_longitude,
  end_latitude, end_longitude, bike_id, user_type, birth_year, gender,
  ride_id, rideable_type
)
SELECT
  trip_duration,
  start_time,
  stop_time,
  start_station_latitude,
  start_station_longitude,
  end_station_latitude,
  end_station_longitude,
  bike_id,
  user_type,
  nullif(nullif(birth_year, ''), 'NULL')::numeric::int AS birth_year,
  nullif(nullif(gender, ''), 'NULL')::numeric::int AS gender,
  ride_id,
  rideable_type
FROM trips_raw
WHERE start_station_id IS NULL
  OR end_station_id IS NULL;

TRUNCATE TABLE trips_raw;
