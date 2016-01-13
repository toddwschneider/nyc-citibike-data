INSERT INTO stations (id, name, latitude, longitude)
SELECT DISTINCT start_station_id, start_station_name, start_station_latitude, start_station_longitude
FROM trips_raw
WHERE start_station_id NOT IN (SELECT id FROM stations);

INSERT INTO stations (id, name, latitude, longitude)
SELECT DISTINCT end_station_id, end_station_name, end_station_latitude, end_station_longitude
FROM trips_raw
WHERE end_station_id NOT IN (SELECT id FROM stations);

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

INSERT INTO trips
(trip_duration, start_time, stop_time, start_station_id, end_station_id, bike_id, user_type, birth_year, gender)
SELECT 
  trip_duration, start_time, stop_time, start_station_id, end_station_id, bike_id, user_type,
  NULLIF(birth_year, '')::int, NULLIF(gender, '')::int
FROM trips_raw;

TRUNCATE TABLE trips_raw;
