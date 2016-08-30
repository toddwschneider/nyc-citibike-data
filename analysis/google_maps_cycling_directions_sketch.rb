require 'rubygems'
require 'rest-client'
require 'json'
require 'polylines'

# this ignores some work to connect to a postgres database that contains the `trips` and `stations` tables,
# but the basic idea is to use the Google Maps Directions API to get cycling directions as JSON, then
# use the polylines gem to decode directions into a series of lat/long coordinates

class Station < ActiveRecord::Base; end

class Trip < ActiveRecord::Base
  BASE_GOOGLE_URL = 'http://maps.googleapis.com/maps/api/directions/json'
  GOOGLE_API_KEY = 'YOUR_API_KEY_HERE' # see https://developers.google.com/maps/documentation/directions/?hl=en

  belongs_to :start_station, class_name: 'Station'
  belongs_to :end_station, class_name: 'Station'

  def google_directions_url
    qry = {
      origin: [start_station.latitude, start_station.longitude].map(&:to_f).join(','),
      destination: [end_station.latitude, end_station.longitude].map(&:to_f).join(','),
      mode: 'bicycling',
      key: GOOGLE_API_KEY
    }.to_query

    "#{BASE_GOOGLE_URL}?#{qry}"
  end

  def fetch_directions_json
    JSON.parse(RestClient.get(google_directions_url))
  end

  def convert_directions_to_line_segments(options = {})
    steps = fetch_directions_json['routes'].first['legs'].first['steps']

    leg_counter = 1
    legs = []

    steps.each do |step|
      polyline = step['polyline']['points']
      points = Polylines::Decoder.decode_polyline(polyline)

      points.each_cons(2) do |(lat1, lon1), (lat2, lon2)|
        h = {
          number: leg_counter,
          start_station_id: start_station_id,
          end_station_id: end_station_id,
          start_latitude: lat1,
          start_longitude: lon1,
          end_latitude: lat2,
          end_longitude: lon2
        }

        legs << h

        leg_counter += 1
      end
    end
  end
end
