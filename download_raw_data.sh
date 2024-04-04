cat raw_data_urls.txt | xargs -n 1 -P 2 wget -P data/
unzip 'data/*.zip' -d data/

# delete some files that are duplicated in raw data
rm data/2013-citibike-tripdata/2013*-citibike-tripdata*.csv
rm data/2018-citibike-tripdata/2018*-citibike-tripdata*.csv
