INSERT INTO stations (normalized_id, name, latitude, longitude)
WITH counts AS (
  SELECT
    normalize_station_id(end_station_id, start_time) AS normalized_id,
    end_station_name,
    nullif(round(end_station_latitude, 4), 0) AS rounded_latitude,
    nullif(round(end_station_longitude, 4), 0) AS rounded_longitude,
    count(*) AS trips
  FROM trips_raw
  WHERE end_station_id IS NOT NULL
  GROUP BY normalized_id, end_station_name, rounded_latitude, rounded_longitude
)
SELECT DISTINCT ON (normalized_id)
  normalized_id,
  end_station_name AS name,
  rounded_latitude AS latitude,
  rounded_longitude AS longitude
FROM counts
ORDER BY normalized_id, trips DESC, end_station_name, rounded_latitude, rounded_longitude
ON CONFLICT (normalized_id) DO UPDATE
  SET name = EXCLUDED.name,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude;

INSERT INTO stations (normalized_id, name, latitude, longitude)
WITH counts AS (
  SELECT
    normalize_station_id(start_station_id, start_time) AS normalized_id,
    start_station_name,
    nullif(round(start_station_latitude, 4), 0) AS rounded_latitude,
    nullif(round(start_station_longitude, 4), 0) AS rounded_longitude,
    count(*) AS trips
  FROM trips_raw
  WHERE start_station_id IS NOT NULL
  GROUP BY normalized_id, start_station_name, rounded_latitude, rounded_longitude
)
SELECT DISTINCT ON (normalized_id)
  normalized_id,
  start_station_name AS name,
  rounded_latitude AS latitude,
  rounded_longitude AS longitude
FROM counts
ORDER BY normalized_id, trips DESC, start_station_name, rounded_latitude, rounded_longitude
ON CONFLICT DO NOTHING;

INSERT INTO trips
(
  trip_duration, start_time, stop_time, start_station_id, end_station_id,
  bike_id, user_type, birth_year, gender, ride_id, rideable_type
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
  rideable_type
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
