# usage:
# ruby update_citibike_stations_data.rb

require 'csv'
require 'httparty'

url = "https://account.citibikenyc.com/bikesharefe-gql"

payload = JSON.parse('{"operationName":"GetSystemSupply","variables":{"input":{"regionCode":"BKN","rideablePageLimit":1000}},"query":"query GetSystemSupply($input: SupplyInput) {\n  supply(input: $input) {\n    stations {\n      stationId\n      stationName\n      location {\n        lat\n        lng\n        __typename\n      }\n      bikesAvailable\n      bikeDocksAvailable\n      ebikesAvailable\n      scootersAvailable\n      totalBikesAvailable\n      totalRideablesAvailable\n      isValet\n      isOffline\n      isLightweight\n      notices {\n        ...NoticeFields\n        __typename\n      }\n      siteId\n      ebikes {\n        batteryStatus {\n          distanceRemaining {\n            value\n            unit\n            __typename\n          }\n          percent\n          __typename\n        }\n        __typename\n      }\n      scooters {\n        batteryStatus {\n          distanceRemaining {\n            value\n            unit\n            __typename\n          }\n          percent\n          __typename\n        }\n        __typename\n      }\n      lastUpdatedMs\n      __typename\n    }\n    rideables {\n      rideableId\n      location {\n        lat\n        lng\n        __typename\n      }\n      rideableType\n      batteryStatus {\n        distanceRemaining {\n          value\n          unit\n          __typename\n        }\n        percent\n        __typename\n      }\n      __typename\n    }\n    notices {\n      ...NoticeFields\n      __typename\n    }\n    requestErrors {\n      ...NoticeFields\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment NoticeFields on Notice {\n  localizedTitle\n  localizedDescription\n  url\n  __typename\n}"}')

headers = {"content-type" => "application/json"}

r = HTTParty.post(url, {body: payload.to_json, headers: headers})

stations_data = r.parsed_response.dig("data", "supply", "stations").map do |s|
  id = s.fetch("siteId")
  name = s.fetch("stationName")

  if id =~ /^\d+\.\d$/
    id = "#{id}0"
    puts "Normalizing #{name} station ID from '#{s.fetch("siteId")}' to '#{id}'"
  end

  [id, name, s.dig("location", "lat"), s.dig("location", "lng")]
end

file_path = "data/citibike_stations_data.csv"

CSV.open("data/citibike_stations_data.csv", "wb") do |csv|
  csv << %w(id name latitude longitude)
  stations_data.sort_by(&:first).each { |s| csv << s }
end

puts "Wrote #{stations_data.size} stations to #{file_path}"
