CREATE INDEX ON trips (start_station_id);
CREATE INDEX ON trips (end_station_id);
CREATE INDEX ON trips USING BRIN (start_time) WITH (pages_per_range = 32);
