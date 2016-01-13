# NYC Citi Bike Data

Code in support of this post: []()

This repo provides scripts to download, process, and analyze data for NYC's [Citi Bike system data](https://www.citibikenyc.com/system-data). The data is stored in a [PostgreSQL](http://www.postgresql.org/) database, uses [PostGIS](http://postgis.net/) for spatial calculations, and [R](https://www.r-project.org/) for data analysis.

Pretty much a copy of [the taxi/Uber data repo](https://github.com/toddwschneider/nyc-taxi-data), at some point the Citi Bike, taxi, and Uber datasets could probably be combined into a single unified NYC transit database...

## Instructions

##### 1. Install [PostgreSQL](http://www.postgresql.org/download/) and [PostGIS](http://postgis.net/install)

Both are available via [Homebrew](http://brew.sh/) on Mac OS X

##### 2. Download raw taxi data

`./download_raw_data.sh`

##### 3. Initialize database and set up schema

`./initialize_database.sh`

##### 4. Import taxi data into database and map to census tracts

`./import_trips.sh`

##### 5. Analysis

Additional Postgres and [R](https://www.r-project.org/) scripts for analysis are in the <code>analysis/</code> folder

## Other data sources

These are bundled with the repository, so no need to download separately, but:

- Shapefile for NYC census tracts and neighborhood tabulation areas comes from [Bytes of the Big Apple](http://www.nyc.gov/html/dcp/html/bytes/districts_download_metadata.shtml)
- Central Park weather data comes from the [National Climatic Data Center](http://www.ncdc.noaa.gov/)

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
