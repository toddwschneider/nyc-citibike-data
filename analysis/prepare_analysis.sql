/*
Note: the database schema has changed a bit since this script was first written,
and I have not updated the code in this file to adapt to the new schema
*/

CREATE TABLE station_to_station_counts AS
SELECT start_station_id, end_station_id, COUNT(*) AS count
FROM trips
WHERE date(start_time) >= '2015-09-01'
GROUP BY start_station_id, end_station_id;
CREATE INDEX idx_station_to_station ON station_to_station_counts (start_station_id, end_station_id);

CREATE TABLE directions_legs (
  id integer primary key,
  station_direction_id integer,
  start_station_id integer,
  end_station_id integer,
  number integer,
  start_latitude numeric(9, 6),
  start_longitude numeric(9, 6),
  end_latitude numeric(9, 6),
  end_longitude numeric(9, 6),
  duration numeric(9, 6)
);

-- see google_maps_cycling_directions_sketch.rb for a sketch of how to get directions via the Google Maps API
COPY directions_legs FROM 'data/individual_legs.csv' CSV HEADER;
CREATE UNIQUE INDEX idx_directions_legs ON directions_legs (start_station_id, end_station_id, number);

-- data for static heatmap
CREATE TABLE leg_counts AS
SELECT
  d.start_latitude,
  d.start_longitude,
  d.end_latitude,
  d.end_longitude,
  SUM(s.count) AS total
FROM station_to_station_counts s
  INNER JOIN directions_legs d
  ON s.start_station_id = d.start_station_id
  AND s.end_station_id = d.end_station_id
WHERE s.start_station_id != s.end_station_id
GROUP BY start_latitude, start_longitude, end_latitude, end_longitude;

CREATE TABLE expected_durations AS
SELECT
  start_station_id,
  end_station_id,
  SUM(duration) AS duration_in_seconds,
  SUM(ST_Distance_Sphere(
    ST_MakePoint(start_longitude, start_latitude),
    ST_MakePoint(end_longitude, end_latitude)
  )) AS distance_in_meters
FROM directions_legs
GROUP BY start_station_id, end_station_id;
CREATE INDEX idx_expected_durations ON expected_durations (start_station_id, end_station_id);

/*
weekday holidays:
('2013-07-04', '2013-09-02', '2013-11-28', '2013-11-29', '2013-12-24', '2013-12-25',
'2014-01-01', '2014-01-20', '2014-02-17', '2014-05-26', '2014-07-04', '2014-09-01', '2014-11-27', '2014-11-28', '2014-12-24', '2014-12-25',
'2015-01-01', '2015-01-19', '2015-02-16', '2015-05-25', '2015-07-03', '2015-09-07', '2015-11-26', '2015-11-27', '2015-12-24', '2015-12-25')
*/

-- setup for analysis of actual times vs. Google Maps cycling directions estimates
CREATE TABLE weekday_rush_hour_data AS
SELECT
  t.id AS trip_id,
  CASE t.gender
    WHEN 1 THEN 'male'
    WHEN 2 THEN 'female'
    ELSE 'unknown'
  END AS gender,
  EXTRACT(YEAR FROM t.start_time) - t.birth_year AS age,
  t.user_type,
  t.trip_duration,
  e.duration_in_seconds AS expected_duration,
  e.distance_in_meters
FROM trips t
  INNER JOIN expected_durations e
  ON t.start_station_id = e.start_station_id
  AND t.end_station_id = e.end_station_id
WHERE t.trip_duration < 60 * 60 * 1.5
  AND e.duration_in_seconds > 120
  AND EXTRACT(DOW FROM t.start_time) IN (1, 2, 3, 4, 5)
  AND EXTRACT(HOUR FROM t.start_time) IN (7, 8, 9, 17, 18, 19)
  AND date(t.start_time) NOT IN ('2013-07-04', '2013-09-02', '2013-11-28', '2013-11-29', '2013-12-24', '2013-12-25', '2014-01-01', '2014-01-20', '2014-02-17', '2014-05-26', '2014-07-04', '2014-09-01', '2014-11-27', '2014-11-28', '2014-12-24', '2014-12-25', '2015-01-01', '2015-01-19', '2015-02-16', '2015-05-25', '2015-07-03', '2015-09-07', '2015-11-26', '2015-11-27', '2015-12-24', '2015-12-25');

-- number of stations in service
CREATE TABLE daily_unique_station_ids AS
SELECT DISTINCT date(start_time) AS date, start_station_id AS station_id FROM trips
UNION
SELECT DISTINCT date(start_time) AS date, end_station_id AS station_id FROM trips;
CREATE UNIQUE INDEX idx_daily_unique_stations ON daily_unique_station_ids (date, station_id);

CREATE TABLE monthly_active_stations AS
SELECT
  date(d) AS date,
  COUNT(DISTINCT s.station_id) AS stations
FROM generate_series('2013-08-01'::date, '2015-12-31'::date, '1 day'::interval) d,
     daily_unique_station_ids s
WHERE s.date <= date(d)
  AND s.date >= date(d) - '27 days'::interval
GROUP BY date(d)
ORDER BY date(d);

-- daily stats plus weather data
CREATE TABLE aggregate_data_with_weather AS
WITH aggregate_data AS (
  SELECT
    date(start_time) AS date,
    COUNT(*) AS trips
  FROM trips
  GROUP BY date(start_time)
)
SELECT
  a.*,
  w.precipitation,
  w.snow_depth,
  w.snowfall,
  w.max_temperature,
  w.min_temperature,
  w.average_wind_speed,
  EXTRACT(DOW FROM a.date) AS dow,
  EXTRACT(YEAR FROM a.date) AS year,
  EXTRACT(MONTH FROM a.date) AS month,
  a.date IN ('2013-07-04', '2013-09-02', '2013-11-28', '2013-11-29', '2013-12-24', '2013-12-25', '2014-01-01', '2014-01-20', '2014-02-17', '2014-05-26', '2014-07-04', '2014-09-01', '2014-11-27', '2014-11-28', '2014-12-24', '2014-12-25', '2015-01-01', '2015-01-19', '2015-02-16', '2015-05-25', '2015-07-03', '2015-09-07', '2015-11-26', '2015-11-27', '2015-12-24', '2015-12-25') AS holiday,
  s.stations AS stations_in_service
FROM aggregate_data a
  INNER JOIN central_park_weather_observations w
    ON a.date = w.date
  LEFT JOIN monthly_active_stations s
    ON a.date = s.date
ORDER BY a.date;

CREATE TABLE station_aggregates_with_weather AS
WITH aggregate_data AS (
  SELECT
    date(start_time) AS date,
    start_station_id AS station_id,
    COUNT(*) AS trips
  FROM trips
  GROUP BY date, start_station_id
)
SELECT
  a.*,
  w.precipitation,
  w.snow_depth,
  w.snowfall,
  w.max_temperature,
  w.min_temperature,
  w.average_wind_speed,
  EXTRACT(DOW FROM a.date) AS dow,
  EXTRACT(YEAR FROM a.date) AS year,
  EXTRACT(MONTH FROM a.date) AS month,
  a.date IN ('2013-07-04', '2013-09-02', '2013-11-28', '2013-11-29', '2013-12-24', '2013-12-25', '2014-01-01', '2014-01-20', '2014-02-17', '2014-05-26', '2014-07-04', '2014-09-01', '2014-11-27', '2014-11-28', '2014-12-24', '2014-12-25', '2015-01-01', '2015-01-19', '2015-02-16', '2015-05-25', '2015-07-03', '2015-09-07', '2015-11-26', '2015-11-27', '2015-12-24', '2015-12-25') AS holiday,
  s.name,
  s.ntaname,
  s.boroname,
  s.nyct2010_gid
FROM aggregate_data a
  INNER JOIN central_park_weather_observations w
    ON a.date = w.date
  INNER JOIN stations s
    ON a.station_id = s.id
ORDER BY a.station_id, a.date;

CREATE TABLE aggregate_data_hourly AS
SELECT
  EXTRACT(HOUR FROM start_time) AS hour,
  EXTRACT(DOW FROM start_time) BETWEEN 1 AND 5 AS weekday,
  COUNT(*) AS trips,
  COUNT(DISTINCT date(start_time)) AS number_of_days
FROM trips
WHERE date(start_time) >= '2015-09-01'
GROUP BY hour, weekday;

CREATE TABLE rush_hour_station_to_station_counts AS
SELECT start_station_id, end_station_id, COUNT(*) AS count
FROM trips
WHERE date(start_time) >= '2015-09-01'
  AND EXTRACT(DOW FROM start_time) IN (1, 2, 3, 4, 5)
  AND EXTRACT(HOUR FROM start_time) IN (7, 8, 9, 17, 18, 19)
GROUP BY start_station_id, end_station_id;
CREATE INDEX idx_station_to_station ON rush_hour_station_to_station_counts (start_station_id, end_station_id);

-- can use rush_hour_station_counts in these queries to get rush hour only
SELECT
  c.*, ss.name, es.name, ss.ntaname, es.ntaname
FROM station_to_station_counts c,
     stations ss,
     stations es
WHERE c.start_station_id = ss.id
  AND c.end_station_id = es.id
ORDER BY c.count DESC;

SELECT
  ss.ntaname, es.ntaname, SUM(COUNT) AS total
FROM station_to_station_counts c,
     stations ss,
     stations es
WHERE c.start_station_id = ss.id
  AND c.end_station_id = es.id
GROUP BY ss.ntaname, es.ntaname
ORDER BY total DESC;

CREATE TABLE weekday_station_to_station_hourly AS
SELECT
  date(start_time) AS date,
  EXTRACT(HOUR FROM start_time) AS hour,
  start_station_id,
  end_station_id,
  COUNT(*) AS trips
FROM trips
WHERE date(start_time) >= '2015-09-01'
  AND EXTRACT(DOW FROM start_time) BETWEEN 1 AND 5
GROUP BY date, hour, start_station_id, end_station_id;

CREATE TABLE boros_hourly AS
SELECT
  h.hour,
  CASE WHEN ss.boroname = 'Manhattan' THEN 'Manhattan' ELSE 'Outer Boroughs' END AS start_boro,
  CASE WHEN es.boroname = 'Manhattan' THEN 'Manhattan' ELSE 'Outer Boroughs' END AS end_boro,
  SUM(trips) AS total,
  COUNT(DISTINCT date) AS number_of_days
FROM weekday_station_to_station_hourly h,
     stations ss,
     stations es
WHERE h.start_station_id = ss.id
  AND h.end_station_id = es.id
GROUP BY hour, start_boro, end_boro
ORDER BY hour, start_boro, end_boro;

-- see how often bikes "magically" transport from one station to another
CREATE TABLE daily_unique_bike_ids AS
SELECT DISTINCT date(start_time) AS date, bike_id
FROM trips
ORDER BY date;
CREATE INDEX idx_daily_unique_bikes ON daily_unique_bike_ids (date);

CREATE TABLE monthly_active_bikes AS
SELECT
  date(d) AS date,
  COUNT(DISTINCT b.bike_id) AS bikes
FROM generate_series('2013-08-01'::date, '2015-12-31'::date, '1 day'::interval) d,
     daily_unique_bike_ids b
WHERE b.date <= date(d)
  AND b.date >= date(d) - '27 days'::interval
GROUP BY date(d)
ORDER BY date(d);

CREATE TABLE bike_station_ids AS
SELECT
  id,
  bike_id,
  start_time,
  stop_time,
  end_station_id,
  lead(start_station_id, 1) OVER w AS next_start_station_id,
  lead(start_time, 1) OVER w AS next_start_time
FROM trips
WINDOW w AS (PARTITION BY bike_id ORDER BY start_time)
ORDER BY bike_id, start_time;
DELETE FROM bike_station_ids WHERE next_start_station_id IS NULL;

CREATE TABLE station_aggregates AS
SELECT
  end_station_id,
  COUNT(*)::numeric AS total_drop_offs,
  SUM((end_station_id != next_start_station_id)::int) AS transported_to_other_station
FROM bike_station_ids
GROUP BY end_station_id;

CREATE TABLE monthly_station_aggregates AS
SELECT
  date(date_trunc('month', stop_time)) AS month,
  end_station_id,
  COUNT(*)::numeric AS total_drop_offs,
  SUM((end_station_id != next_start_station_id)::int) AS transported_to_other_station
FROM bike_station_ids
GROUP BY end_station_id, month;

CREATE TABLE hourly_station_aggregates AS
SELECT
  EXTRACT(HOUR FROM stop_time) AS hour,
  end_station_id,
  COUNT(*)::numeric AS total_drop_offs,
  SUM((end_station_id != next_start_station_id)::int) AS transported_to_other_station
FROM bike_station_ids
GROUP BY end_station_id, hour;

SELECT SUM(transported_to_other_station) / SUM(total_drop_offs)
FROM station_aggregates;

SELECT
  ntaname,
  SUM(transported_to_other_station) / SUM(total_drop_offs) frac,
  SUM(total_drop_offs) total
FROM station_aggregates a
  INNER JOIN stations s
  ON a.end_station_id = s.id
GROUP BY ntaname
ORDER BY frac DESC;

SELECT
  ntaname,
  hour,
  SUM(transported_to_other_station) / SUM(total_drop_offs) frac,
  SUM(total_drop_offs) total
FROM hourly_station_aggregates a
  INNER JOIN stations s
  ON a.end_station_id = s.id
GROUP BY ntaname, hour
HAVING SUM(total_drop_offs) > 1000
ORDER BY ntaname, hour;

-- anonymous trips
CREATE TABLE anonymous_analysis_hourly AS
SELECT
  date_trunc('hour', start_time) truncated_to_hour,
  start_station_id,
  gender,
  EXTRACT(YEAR FROM start_time) - birth_year AS age,
  COUNT(*) count
FROM trips
WHERE
  user_type = 'Subscriber'
  AND gender IN (1, 2)
  AND birth_year IS NOT NULL
  AND birth_year >= 1920
GROUP BY truncated_to_hour, start_station_id, gender, age;

CREATE TABLE anonymous_analysis_daily AS
SELECT
  date(start_time) truncated_to_day,
  start_station_id,
  gender,
  EXTRACT(YEAR FROM start_time) - birth_year AS age,
  COUNT(*) count
FROM trips
WHERE
  user_type = 'Subscriber'
  AND gender IN (1, 2)
  AND birth_year IS NOT NULL
  AND birth_year >= 1920
GROUP BY truncated_to_day, start_station_id, gender, age;

SELECT SUM(CASE WHEN count = 1 THEN 1.0 ELSE 0 END) / SUM(count) AS uniq_frac
FROM anonymous_analysis_hourly;

SELECT SUM(CASE WHEN count = 1 THEN 1.0 ELSE 0 END) / SUM(count) AS uniq_frac
FROM anonymous_analysis_daily;
