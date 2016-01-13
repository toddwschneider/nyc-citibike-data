CREATE INDEX idx_trips_on_start_station ON trips (start_station_id);
CREATE INDEX idx_trips_on_end_station ON trips (end_station_id);
CREATE INDEX idx_trips_on_dow ON trips (EXTRACT(DOW FROM start_time));
CREATE INDEX idx_trips_on_hour ON trips (EXTRACT(HOUR FROM start_time));
CREATE INDEX idx_trips_on_date ON trips (date(start_time));
