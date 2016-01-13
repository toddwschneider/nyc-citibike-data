library(ggplot2)
library(dplyr)
library(reshape2)
library(zoo)
library(scales)
library(extrafont)
library(grid)
library(RPostgreSQL)
library(ggmap)
library(rgdal)
library(maptools)
library(readr)
library(minpack.lm)
gpclibPermit()
source("helpers.R")

tracts = spTransform(readOGR("../nyct2010_15b", layer = "nyct2010"), CRS("+proj=longlat +datum=WGS84"))
tracts@data$id = as.character(as.numeric(rownames(tracts@data)) + 1)
tracts.points = fortify(tracts, region = "id")
tracts.map = inner_join(tracts.points, tracts@data, by = "id")

nyc_map = tracts.map
ex_staten_island_map = filter(tracts.map, BoroName != "Staten Island")
manhattan_map = filter(tracts.map, BoroName == "Manhattan")
governors_island = filter(ex_staten_island_map, BoroCT2010 == "1000500")

# overview
daily = query("SELECT date, dow, trips FROM aggregate_data_with_weather ORDER BY date")
daily = daily %>%
  mutate(dow = factor(dow, labels = c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")),
         monthly = rollsum(trips, k = 28, na.pad = TRUE, align = "right"))

png(filename = "graphs/monthly_total_trips.png", width = 640, height = 480)
ggplot(data = daily, aes(x = date, y = monthly)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_date("") +
  scale_y_continuous("Citi Bike trips, trailing 28 days\n", labels = comma) +
  expand_limits(y = 0) +
  title_with_subtitle("NYC Monthly Citi Bike Trips", "Based on Citi Bike system data") +
  theme_tws(base_size = 20)
add_credits()
dev.off()

by_dow = daily %>%
  filter(date >= "2015-09-01") %>%
  group_by(dow) %>%
  summarize(avg = mean(trips))

png(filename = "graphs/trips_by_dow.png", width = 640, height = 420)
ggplot(data = by_dow, aes(x = dow, y = avg)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_x_discrete("") +
  scale_y_continuous("Avg daily Citi Bike trips\n", labels = comma) +
  expand_limits(y = 0) +
  title_with_subtitle("NYC Citi Bike Trips by Day of Week", "Based on Citi Bike system data 9/2015–11/2015") +
  theme_tws(base_size = 20)
add_credits()
dev.off()

by_hour = query("SELECT * FROM aggregate_data_hourly ORDER BY weekday, hour")
by_hour = by_hour %>%
  mutate(timestamp_for_x_axis = as.POSIXct(hour * 3600, origin = "1970-01-01", tz = "UTC"),
         weekday = factor(weekday, levels = c(TRUE, FALSE), labels = c("Weekdays", "Weekends")),
         avg = trips / number_of_days)

png(filename = "graphs/trips_by_hour.png", width = 640, height = 720)
ggplot(data = by_hour, aes(x = timestamp_for_x_axis, y = avg)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_x_datetime("", labels = date_format("%l %p")) +
  scale_y_continuous("Avg hourly Citi Bike trips\n", labels = comma) +
  title_with_subtitle("NYC Citi Bike Trips by Hour of Day", "Based on Citi Bike system data 9/2015–11/2015") +
  facet_wrap(~weekday, ncol = 1) +
  theme_tws(base_size = 20) +
  theme(strip.background = element_blank(),
        strip.text = element_text(size = rel(1)),
        panel.margin = unit(1.2, "lines"))
add_credits()
dev.off()

by_boro = query("SELECT * FROM boros_hourly ORDER BY hour, start_boro, end_boro")

by_boro = by_boro %>%
  mutate(timestamp_for_x_axis = as.POSIXct(hour * 3600, origin = "1970-01-01", tz = "UTC"),
         name = paste(start_boro, "to", end_boro),
         avg = total / number_of_days)

png(filename = "graphs/manhattan_vs_outer_boroughs.png", width = 640, height = 520)
ggplot(data = filter(by_boro, name %in% c("Manhattan to Outer Boroughs", "Outer Boroughs to Manhattan")),
       aes(x = timestamp_for_x_axis, y = avg, color = name)) +
  geom_line(size = 1) +
  scale_x_datetime("", labels = date_format("%l %p")) +
  scale_y_continuous("Avg Citi Bike trips, hourly\n", labels = comma) +
  scale_color_manual("", values = c(citi_hex, orange_hex)) +
  title_with_subtitle("NYC Citi Bike Trips Between Manhattan and Outer Boroughs", "Based on Citi Bike system data, weekdays 9/2015–11/2015") +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom",
        legend.direction = "vertical",
        legend.margin = unit(0, "lines"),
        legend.text = element_text(size = rel(1.1)),
        legend.key.height = unit(1.7, "lines"),
        legend.key.width = unit(2, "lines"))
add_credits()
dev.off()

# routes heatmap
leg_counts = query("SELECT * FROM leg_counts ORDER BY total ASC")

stations = query("
  SELECT id, latitude, longitude, name, boroname, ntaname
  FROM stations
  WHERE id IN (SELECT DISTINCT start_station_id FROM trips WHERE date(start_time) >= '2015-09-01')
     OR id IN (SELECT DISTINCT end_station_id FROM trips WHERE date(start_time) >= '2015-09-01')
  ORDER BY id
")

png(filename = "graphs/most_popular_bike_routes.png", width = 480, height = 800, bg = "black")
ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808", alpha = 0.5) +
  geom_leg(data = leg_counts,
           aes(x = start_longitude, xend = end_longitude,
               y = start_latitude, yend = end_latitude,
               size = total, color = total, alpha = total)) +
  geom_point(data = stations,
             aes(x = longitude, y = latitude),
             color = "#ffa500", alpha = 0.5, size = 1) +
  scale_size_continuous(range = c(0.3, 3)) +
  scale_color_gradient(low = "#555555", high = "#ffffff", trans = "sqrt") +
  scale_alpha_continuous(range = c(0.6, 1), trans = "sqrt") +
  coord_map(xlim = c(-74.03, -73.929), ylim = c(40.674, 40.793)) +
  title_with_subtitle("NYC Citi Bike Most Popular Roads", "Sep—Nov 2015") +
  theme_dark_map(base_size = 24) +
  theme(legend.position = "none")
add_credits(color = "#dddddd", ypos = 0.015)
dev.off()

png(filename = "graphs/most_popular_bike_routes_hires.png", width = 1440, height = 2500, bg = "black")
ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808") +
  geom_leg(data = leg_counts,
           aes(x = start_longitude, xend = end_longitude,
               y = start_latitude, yend = end_latitude,
               size = total, color = total, alpha = total)) +
  geom_point(data = stations,
             aes(x = longitude, y = latitude),
             color = "#ffa500", alpha = 0.5, size = 4) +
  scale_size_continuous(range = c(0.6, 9)) +
  scale_color_gradient(low = "#999999", high = "#ffffff", trans = "sqrt") +
  scale_alpha_continuous(range = c(0.6, 1), trans = "sqrt") +
  coord_map(xlim = c(-74.03, -73.929), ylim = c(40.674, 40.793)) +
  title_with_subtitle("NYC Citi Bike Most Popular Roads", "Sep—Nov 2015") +
  theme_dark_map(base_size = 72) +
  theme(legend.position = "none")
add_credits(color = "#dddddd", ypos = 0.012, fontsize = 36)
dev.off()

# actual trip times vs. expected times according to Google Maps cycling directions
rush_hour_data = query("SELECT * FROM weekday_rush_hour_data")

miles_per_meter = 1 / (5280 * 12 * 2.54 / 100)
hours_per_second = 1 / (60 * 60)

rush_hour_data = rush_hour_data %>%
  mutate(difference = as.numeric(trip_duration - expected_duration),
         distance_in_miles = as.numeric(distance_in_meters * miles_per_meter))

rush_hour_data = rush_hour_data %>%
  mutate(trip_mph = distance_in_miles / (hours_per_second * trip_duration),
         expected_mph = distance_in_miles / (hours_per_second * expected_duration),
         expected_bucket = cut(expected_duration, breaks = c(0, 300, 600, 900, 1200, 4500), right = FALSE),
         age_bucket = cut(age, breaks = c(0, 22, 25, 30, 35, 40, 45, 50, 60, 100), right = FALSE),
         distance_bucket = cut(distance_in_miles, breaks = c(0, 1, 1.5, 2, 20), right = FALSE))

levels(rush_hour_data$expected_bucket) = paste("Expected", c("<5", "5–10", "10–15", "15–20", "≥20"), "minutes")
levels(rush_hour_data$distance_bucket) = c("<1 mile", "1–1.5 miles", "1.5–2 miles", "≥2 miles")

# drop trips with extreme speeds: less than 4 mph, or greater than 35 mph
# note these aren't actual speeds, they are avg speeds if riders follow google maps cycling directions
quantile(rush_hour_data$trip_mph, c(0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99))
rush_hour_data = filter(rush_hour_data, trip_mph > 4, trip_mph < 35)

# daily customers travel much more slowly than subscribers
# for this analysis, we'll focus on subscribers, who account for ~97% of rides in rush_hour_data to this point
rush_hour_data %>%
  group_by(distance_bucket, user_type) %>%
  summarize(mean_diff = mean(difference),
            sd_diff = sd(difference),
            mean_mph = mean(trip_mph),
            sd_mph = sd(trip_mph))

# additionally, drop the small number of records where gender/age are unknown,
# and there are a bunch of suspcious 19th century birthdays, so drop those too
rush_hour_data = rush_hour_data %>%
  filter(user_type == "Subscriber",
         gender != "unknown",
         !is.na(age),
         age <= 95)

bucketed_data = rush_hour_data %>%
  group_by(distance_bucket, gender, age_bucket) %>%
  summarize(mean_diff = mean(difference),
            median_diff = median(difference),
            sd_diff = sd(difference),
            mean_mph = mean(trip_mph),
            median_mph = median(trip_mph),
            sd_mph = sd(trip_mph),
            count = n(),
            mean_expected = mean(expected_duration),
            mean_age = mean(age))

png(filename = "graphs/mean_mph_by_age_gender_distance.png", width = 640, height = 720)
ggplot(data = filter(bucketed_data, count > 1000),
       aes(x = mean_age, y = mean_mph, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("Age") +
  scale_y_continuous("Miles per hour\n") +
  scale_color_discrete("") +
  title_with_subtitle("NYC Citi Bike Speed by Age, Gender, and Trip Distance",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM)") +
  facet_wrap(~distance_bucket, ncol = 2) +
  theme_tws(base_size = 18.5) +
  theme(legend.position = "bottom",
        strip.background = element_blank(),
        strip.text = element_text(size = rel(1)),
        panel.margin = unit(1.2, "lines"))
add_credits()
dev.off()

png(filename = "graphs/mean_actual_time_vs_expected_age_gender.png", width = 640, height = 720)
ggplot(data = filter(bucketed_data, count > 1000),
       aes(x = mean_age, y = mean_diff / 60, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("Age") +
  scale_y_continuous("Mean actual trip time minus expected, in minutes\n") +
  scale_color_discrete("") +
  geom_hline(yintercept = 0, color = "#999999", linetype = 2) +
  title_with_subtitle("NYC Citi Bike Trip Times vs. Google Estimates by Age/Gender",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM)") +
  facet_wrap(~distance_bucket, ncol = 2) +
  theme_tws(base_size = 18.5) +
  theme(legend.position = "bottom",
        strip.background = element_blank(),
        strip.text = element_text(size = rel(1)),
        panel.margin = unit(1.2, "lines"))
add_credits()
dev.off()

png(filename = "graphs/median_actual_time_vs_expected_age_gender.png", width = 640, height = 720)
ggplot(data = filter(bucketed_data, count > 1000),
       aes(x = mean_age, y = median_diff / 60, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("Age") +
  scale_y_continuous("Median actual trip time minus expected, in minutes\n") +
  scale_color_discrete("") +
  geom_hline(yintercept = 0, color = "#999999", linetype = 2) +
  title_with_subtitle("NYC Citi Bike Trip Times vs. Google Estimates by Age/Gender",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM)") +
  facet_wrap(~distance_bucket, ncol = 2) +
  theme_tws(base_size = 18.5) +
  theme(legend.position = "bottom",
        strip.background = element_blank(),
        strip.text = element_text(size = rel(1)),
        panel.margin = unit(1.2, "lines"))
add_credits()
dev.off()

age_granular = rush_hour_data %>%
  filter(distance_in_miles >= 1, distance_in_miles < 1.5) %>%
  group_by(age, gender) %>%
  summarize(count = n(),
            mean_diff = mean(difference)) %>%
  filter(count > 1000)

png(filename = "graphs/mean_actual_time_vs_expected_age_granular.png", width = 640, height = 480)
ggplot(data = age_granular,
       aes(x = age, y = mean_diff / 60, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("\nAge") +
  scale_y_continuous("Actual trip time minus expected, in minutes\n") +
  scale_color_discrete("") +
  title_with_subtitle("NYC Citi Bike Trip Times vs. Google Estimates by Age",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM), 1–1.5 mile trips") +
  theme_tws(base_size = 17) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

distance_granular = rush_hour_data %>%
  filter(age >= 25, age <= 35) %>%
  mutate(granular_distance_bucket = round(distance_in_miles, 1)) %>%
  group_by(granular_distance_bucket, gender) %>%
  summarize(count = n(),
            mean_distance = mean(distance_in_miles),
            mean_diff = mean(difference),
            mean_mph = mean(trip_mph)) %>%
  filter(count > 1000)

png(filename = "graphs/mean_actual_time_vs_expected_distance_granular.png", width = 640, height = 480)
ggplot(data = distance_granular,
       aes(x = mean_distance, y = mean_diff / 60, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("\nDistance in miles") +
  scale_y_continuous("Actual trip time minus expected, in minutes\n") +
  scale_color_discrete("") +
  title_with_subtitle("NYC Citi Bike Trip Times vs. Google Estimates by Trip Distance",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM), ages 25–35") +
  theme_tws(base_size = 17) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

png(filename = "graphs/mean_mph_distance_granular.png", width = 640, height = 480)
ggplot(data = distance_granular,
       aes(x = mean_distance, y = mean_mph, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("\nDistance in miles") +
  scale_y_continuous("Miles per hour\n") +
  scale_color_discrete("") +
  title_with_subtitle("NYC Citi Bike Speed by Trip Distance",
                      "7/2013–11/2015, Citi Bike subscribers, weekday rush hour (7–10AM, 5–8PM), ages 25–35") +
  theme_tws(base_size = 17) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

linear_model = lm(difference ~ gender + age + distance_in_miles, data = rush_hour_data)
summary(linear_model)
rush_hour_data$predicted_linear = predict(linear_model)

gender_results = rush_hour_data %>%
  group_by(gender) %>%
  summarize(mean_diff = mean(difference),
            predicted_diff = mean(predicted_linear),
            error = mean_diff - predicted_diff,
            count = n()) %>%
  filter(count > 1000)

age_results = rush_hour_data %>%
  group_by(age) %>%
  summarize(mean_diff = mean(difference),
            predicted_diff = mean(predicted_linear),
            error = mean_diff - predicted_diff,
            count = n()) %>%
  filter(count > 1000)

distance_results = rush_hour_data %>%
  mutate(granular_distance_bucket = round(distance_in_miles, 1)) %>%
  group_by(granular_distance_bucket) %>%
  summarize(mean_diff = mean(difference),
            predicted_diff = mean(predicted_linear),
            error = mean_diff - predicted_diff,
            count = n()) %>%
  filter(count > 1000)

png(filename = "graphs/linear_model_error_by_age.png", width = 640, height = 480)
ggplot(data = age_results, aes(x = age, y = error / 60)) +
  geom_line(size = 1) +
  scale_x_continuous("Age") +
  scale_y_continuous("(actual - expected) error, in minutes\n") +
  title_with_subtitle("Linear Model Error by Age",
                      "Model predicts difference between actual trip time and Google Maps estimate") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

png(filename = "graphs/linear_model_error_by_distance.png", width = 640, height = 480)
ggplot(data = distance_results, aes(x = granular_distance_bucket, y = error / 60)) +
  geom_line(size = 1) +
  scale_x_continuous("\nDistance in miles") +
  scale_y_continuous("(actual - expected) error, in minutes\n") +
  title_with_subtitle("Linear Model Error by Age",
                      "Model predicts difference between actual trip time and Google Maps estimate") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

# number of trips vs. weather
weather_data = query("SELECT * FROM aggregate_data_with_weather ORDER BY date")
weather_data = weather_data %>%
  mutate(weekday = dow %in% 1:5,
         weekday_non_holiday = dow %in% 1:5 & !holiday)
write_csv(weather_data, "../data/daily_citi_bike_trip_counts_and_weather.csv")

scurve = function(x, center, width) {
  1 / (1 + exp(-(x - center) / width))
}

nls_model = nlsLM(
  trips ~ exp(
            const +
            b_weekday * weekday_non_holiday +
            b_expansion * (date > "2015-08-25")
          ) +
          b_weather * scurve(
            max_temperature + b_precip * precipitation + b_snow * snow_depth,
            weather_scurve_center,
            weather_scurve_width
          ),
  data = filter(weather_data, date >= "2013-08-01"),
  start = list(const = 9,
               b_weekday = 1,
               b_expansion = 1,
               b_weather = 25000,
               b_precip = -20, b_snow = -2,
               weather_scurve_center = 40,
               weather_scurve_width = 20))

summary(nls_model)
sqrt(mean(summary(nls_model)$residuals^2))
# rmse = 4,138

weather_data = weather_data %>%
  mutate(predicted_nls = predict(nls_model, newdata = weather_data),
         resid = trips - predicted_nls)

trips_by_temperature = weather_data %>%
  filter(weekday, !holiday, precipitation == 0, snow_depth == 0) %>%
  mutate(temperature_bucket = floor(max_temperature / 5) * 5) %>%
  group_by(temperature_bucket) %>%
  summarize(actual = mean(trips),
            avg_max_temperature = mean(max_temperature),
            predicted = mean(predicted_nls),
            count = n()) %>%
  filter(count >= 3)

png("graphs/daily_weekday_trips_vs_temperature.png", width = 640, height = 400)
ggplot(data = trips_by_temperature,
       aes(x = avg_max_temperature, y = actual)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_continuous("\nMax daily temperature (°F)") +
  scale_y_continuous("Average daily Citi Bike trips\n", labels = comma) +
  title_with_subtitle("Temperature vs. NYC Citi Bike Daily Usage",
                      "7/2013–11/2015, weekdays with no rain or snow") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

trips_by_precipitation = weather_data %>%
  filter(weekday, !holiday, snow_depth == 0, max_temperature >= 60) %>%
  mutate(precip_bucket = cut(precipitation, c(0, 0.001, 0.2, 0.4, 0.6, 0.8, 1, 2), right = FALSE)) %>%
  group_by(precip_bucket) %>%
  summarize(actual = mean(trips),
            avg_precip = mean(precipitation),
            predicted = mean(predicted_nls),
            count = n()) %>%
  filter(count >= 3)

png("graphs/daily_weekday_trips_vs_precipitation.png", width = 640, height = 400)
ggplot(data = trips_by_precipitation,
       aes(x = avg_precip, y = actual)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_continuous("\nDaily precipitation, inches") +
  scale_y_continuous("Average daily Citi Bike trips\n", labels = comma) +
  title_with_subtitle("Precipitation vs. NYC Citi Bike Daily Usage",
                      "7/2013–11/2015, weekdays with max temperature ≥ 60 °F") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

trips_by_snow_depth = weather_data %>%
  filter(weekday, !holiday, max_temperature < 40) %>%
  mutate(snow_bucket = cut(snow_depth, c(0, 0.001, 3, 6, 9, 12, 60), right = FALSE)) %>%
  group_by(snow_bucket) %>%
  summarize(actual = mean(trips),
            avg_snow_depth = mean(snow_depth),
            predicted = mean(predicted_nls),
            count = n()) %>%
  filter(count >= 3)

png("graphs/daily_weekday_trips_vs_snow_depth.png", width = 640, height = 400)
ggplot(data = trips_by_snow_depth,
       aes(x = avg_snow_depth, y = actual)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_continuous("\nCentral Park snow depth, inches") +
  scale_y_continuous("Average daily Citi Bike trips\n", labels = comma) +
  title_with_subtitle("Snow Depth vs. NYC Citi Bike Daily Usage",
                      "7/2013–11/2015, weekdays with max temperature < 40 °F") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

png(filename = "graphs/model_results_scatterplot.png", width = 640, height = 640)
ggplot(data = weather_data, aes(x = trips, y = predicted_nls)) +
  geom_point(alpha = 0.7) +
  geom_abline(intercept = 0, slope = 1, color = "blue") +
  scale_x_continuous("\nActual trips per day", labels = comma) +
  scale_y_continuous("Predicted trips per day\n", labels = comma) +
  expand_limits(y = 0, x = 0) +
  title_with_subtitle("Citi Bike Model Predictions") +
  theme_tws(base_size = 20)
add_credits()
dev.off()

png(filename = "graphs/model_residuals_histogram.png", width = 640, height = 480)
ggplot(data = weather_data, aes(x = resid)) +
  geom_histogram(binwidth = 1000) +
  scale_x_continuous("\nResidual (actual - expected)", labels = comma) +
  scale_y_continuous("Count\n", labels = comma) +
  title_with_subtitle("Histogram of Model Residuals") +
  theme_tws(base_size = 20)
add_credits()
dev.off()

predicted_by_date = weather_data %>%
  mutate(actual = rollsum(trips, k = 28, na.pad = TRUE, align = "right"),
         predicted = rollsum(predicted_nls, k = 28, na.pad = TRUE, align = "right")) %>%
  select(date, actual, predicted)

png(filename = "graphs/model_predicted_by_date.png", width = 640, height = 480)
ggplot(data = melt(predicted_by_date, id = "date"),
       aes(x = date, y = value, color = variable)) +
  geom_line(size = 1) +
  scale_x_date("") +
  scale_y_continuous("Trailing 28 day total\n", labels = comma) +
  scale_color_manual("", values = c(citi_hex, orange_hex)) +
  title_with_subtitle("Citi Bike Monthly Trips: Actual vs. Model") +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

cfs = coef(nls_model)
base = exp(cfs['const'] + cfs['b_weekday'] + cfs['b_expansion'])

weather_scurve = data.frame(
  temp = 0:100,
  pred = base + cfs['b_weather'] * scurve(0:100, cfs['weather_scurve_center'], cfs['weather_scurve_width'])
)

png(filename = "graphs/weather_scurve.png", width = 640, height = 320)
ggplot(data = weather_scurve, aes(x = temp, y = pred)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_continuous("\nMax daily temperature (°F)") +
  scale_y_continuous("Daily ridership\n", labels = comma) +
  title_with_subtitle("Predicted Impact of Temperature on Citi Bike Ridership", "Assumes non-holiday weekday with no rain or snow") +
  theme_tws(base_size = 18)
add_credits()
dev.off()

ggplot(data = melt(select(trips_by_temperature, actual, predicted, avg_max_temperature), id = "avg_max_temperature"),
       aes(x = avg_max_temperature, y = value, color = variable)) +
  geom_line(size = 1) +
  scale_x_continuous("") +
  scale_y_continuous("", labels = comma) +
  scale_color_manual("", values = c(citi_hex, orange_hex)) +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")

ggplot(data = melt(select(trips_by_precipitation, actual, predicted, avg_precip), id = "avg_precip"),
       aes(x = avg_precip, y = value, color = variable)) +
  geom_line(size = 1) +
  scale_x_continuous("") +
  scale_y_continuous("", labels = comma) +
  scale_color_manual("", values = c(citi_hex, orange_hex)) +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")

ggplot(data = melt(select(trips_by_snow_depth, actual, predicted, avg_snow_depth), id = "avg_snow_depth"),
       aes(x = avg_snow_depth, y = value, color = variable)) +
  geom_line(size = 1) +
  scale_x_continuous("") +
  scale_y_continuous("", labels = comma) +
  scale_color_manual("", values = c(citi_hex, orange_hex)) +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")


# number of bikes and stations in service
active_bikes = query("SELECT * FROM monthly_active_bikes ORDER BY date")
active_stations = query("SELECT * FROM monthly_active_stations ORDER BY date")

png(filename = "graphs/bikes_used.png", width = 640, height = 480)
ggplot(data = filter(active_bikes, date <= "2015-11-30"), aes(x = date, y = bikes)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_date("") +
  scale_y_continuous("Number of Citi Bikes Used\n", labels = comma) +
  expand_limits(y = 0) +
  title_with_subtitle("Unique Bikes Used Per Day", "Program expansion in August 2015 added nearly 2,000 bikes") +
  theme_tws(base_size = 18)
add_credits()
dev.off()

png(filename = "graphs/stations_in_use.png", width = 640, height = 480)
ggplot(data = filter(active_stations, date <= "2015-11-30"), aes(x = date, y = stations)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_date("") +
  scale_y_continuous("Citi Bike stations in use\n", labels = comma) +
  expand_limits(y = 0) +
  title_with_subtitle("Citi Bike Stations in Use", "Program expansion in August 2015 added nearly 150 stations") +
  theme_tws(base_size = 18)
add_credits()
dev.off()

# bike transports
transports_monthly = query("
  SELECT
    month,
    SUM(transported_to_other_station) / SUM(total_drop_offs) frac
  FROM monthly_station_aggregates
  GROUP BY month
  ORDER BY month
")

png(filename = "graphs/monthly_station_transports.png", width = 640, height = 480)
ggplot(data = transports_monthly, aes(x = month, y = frac)) +
  geom_line(size = 1, color = citi_hex) +
  scale_x_date("") +
  scale_y_continuous("% of bikes transported\n", labels = percent) +
  expand_limits(y = 0) +
  title_with_subtitle("NYC Citi Bike Station-to-Station Transports",
                      "% of bikes that are manually moved to a different station after being dropped off") +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

nta_transports_hourly = query("
  SELECT
    ntaname,
    hour,
    SUM(transported_to_other_station) / SUM(total_drop_offs) frac,
    SUM(total_drop_offs) total
  FROM hourly_station_aggregates a
    INNER JOIN stations s
    ON a.end_station_id = s.id
  GROUP BY ntaname, hour
  HAVING SUM(total_drop_offs) > 100
  ORDER BY ntaname, hour
")
nta_transports_hourly = nta_transports_hourly %>%
  mutate(timestamp_for_x_axis = as.POSIXct(hour * 3600, origin = "1970-01-01", tz = "UTC"))

ntas = c("East Village", "Fort Greene", "Midtown-Midtown South")
for (n in ntas) {
  p = ggplot(data = filter(nta_transports_hourly, ntaname == n),
             aes(x = timestamp_for_x_axis, y = frac)) +
      geom_bar(stat = "identity", fill = citi_hex) +
      scale_x_datetime("\nDrop off hour", labels = date_format("%l %p")) +
      scale_y_continuous("% of bikes transported\n", labels = percent) +
      title_with_subtitle(n, "% of Citi Bikes that are manually moved to a different station after being dropped off") +
      theme_tws(base_size = 18)

  png(filename = paste0("graphs/transports_", to_slug(n), ".png"), width = 640, height = 400)
  print(p)
  add_credits()
  dev.off()
}

privacy = query("
  SELECT
    gender,
    age,
    SUM(CASE WHEN count = 1 THEN 1.0 ELSE 0 END) / SUM(count) AS uniq_frac,
    SUM(count) AS total
  FROM anonymous_analysis_hourly
  WHERE age BETWEEN 16 AND 80
  GROUP BY gender, age
  ORDER BY gender, age
")
privacy = privacy %>%
  mutate(gender = factor(gender, levels = c(2, 1), labels = c("female", "male"))) %>%
  filter(total > 5000)

png(filename = "graphs/uniquely_identifiable.png", width = 640, height = 420)
ggplot(data = privacy, aes(x = age, y = uniq_frac, color = gender)) +
  geom_line(size = 1) +
  scale_x_continuous("Rider age") +
  scale_y_continuous("% of trips uniquely identifiable\n", labels = percent) +
  expand_limits(y = c(0.7, 1)) +
  scale_color_discrete("") +
  title_with_subtitle("Uniquely Identifiable Citi Bike Trips", "Given age, gender, subscriber status, trip's start point and time rounded to nearest hr") +
  theme_tws(base_size = 18) +
  theme(legend.position = "bottom")
add_credits()
dev.off()
