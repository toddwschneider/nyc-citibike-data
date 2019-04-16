INSERT INTO stations (external_id, name, latitude, longitude)
SELECT DISTINCT
  start_station_id,
  start_station_name,
  NULLIF(ROUND(start_station_latitude, 6), 0),
  NULLIF(ROUND(start_station_longitude, 6), 0)
FROM trips_raw
WHERE start_station_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO stations (external_id, name, latitude, longitude)
SELECT DISTINCT
  end_station_id,
  end_station_name,
  NULLIF(ROUND(end_station_latitude, 6), 0),
  NULLIF(ROUND(end_station_longitude, 6), 0)
FROM trips_raw
WHERE end_station_id IS NOT NULL
ON CONFLICT DO NOTHING;

UPDATE stations
SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
WHERE geom IS NULL;

UPDATE stations
SET nyct2010_gid = n.gid,
    boroname = n.boroname,
    ntacode = n.ntacode,
    ntaname = n.ntaname
FROM nyct2010 n
WHERE stations.nyct2010_gid IS NULL
  AND ST_Within(stations.geom, n.geom);

UPDATE stations
SET taxi_zone_gid = z.gid,
    taxi_zone_name = z.zone
FROM taxi_zones z
WHERE stations.taxi_zone_gid IS NULL
  AND ST_Within(stations.geom, z.geom);

INSERT INTO trips
(trip_duration, start_time, stop_time, start_station_id, end_station_id, bike_id, user_type, birth_year, gender)
SELECT
  trip_duration,
  start_time,
  stop_time,
  ss.id,
  es.id,
  bike_id,
  user_type,
  NULLIF(NULLIF(birth_year, ''), 'NULL')::int,
  NULLIF(NULLIF(gender, ''), 'NULL')::int
FROM trips_raw t
  INNER JOIN stations ss
    ON t.start_station_id = ss.external_id
    AND ROUND(t.start_station_longitude, 6) = ss.longitude
    AND ROUND(t.start_station_latitude, 6) = ss.latitude
  INNER JOIN stations es
    ON t.end_station_id = es.external_id
    AND ROUND(t.end_station_longitude, 6) = es.longitude
    AND ROUND(t.end_station_latitude, 6) = es.latitude
WHERE t.start_station_id IS NOT NULL
  AND t.end_station_id IS NOT NULL;

INSERT INTO dockless_trips
(trip_duration, start_time, stop_time, start_latitude, start_longitude, end_latitude, end_longitude, bike_id, user_type, birth_year, gender)
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
  NULLIF(NULLIF(birth_year, ''), 'NULL')::int,
  NULLIF(NULLIF(gender, ''), 'NULL')::int
FROM trips_raw
WHERE start_station_id IS NULL
  OR end_station_id IS NULL;

TRUNCATE TABLE trips_raw;
