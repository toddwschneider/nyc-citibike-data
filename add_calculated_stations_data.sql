INSERT INTO stations (normalized_id, name, latitude, longitude, data_source)
WITH trip_starts AS (
  SELECT
    start_station_id AS station_id,
    start_station_name AS name,
    start_latitude AS latitude,
    start_longitude AS longitude
  FROM trips
  WHERE start_station_id IS NOT NULL
    AND start_station_id NOT IN (SELECT normalized_id FROM stations WHERE data_source = 'citibike_website')
),
trip_ends AS (
  SELECT
    end_station_id AS station_id,
    end_station_name AS name,
    end_latitude AS latitude,
    end_longitude AS longitude
  FROM trips
  WHERE end_station_id IS NOT NULL
    AND end_station_id NOT IN (SELECT normalized_id FROM stations WHERE data_source = 'citibike_website')
),
unioned AS (
  SELECT * FROM trip_starts
  UNION
  SELECT * FROM trip_ends
),
counts AS (
  SELECT
    station_id,
    name,
    round(latitude, 4) AS rounded_latitude,
    round(longitude, 4) AS rounded_longitude,
    count(*) AS trips
  FROM unioned
  GROUP BY station_id, name, rounded_latitude, rounded_longitude
)
SELECT DISTINCT ON (normalized_id)
  station_id AS normalized_id,
  name,
  rounded_latitude AS latitude,
  rounded_longitude AS longitude,
  'trips_data' AS data_source
FROM counts
ORDER BY normalized_id, trips DESC, name, latitude, longitude
ON CONFLICT (normalized_id) DO UPDATE
  SET name = EXCLUDED.name,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      data_source = EXCLUDED.data_source;
