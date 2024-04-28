# NYC Citi Bike Data

Code originally in support of the post ["A Tale of Twenty-Two Million Citi Bike Rides: Analyzing the NYC Bike Share System"](https://toddwschneider.com/posts/a-tale-of-twenty-two-million-citi-bikes-analyzing-the-nyc-bike-share-system/). Also used in conjunction with the [nyc-taxi-data repo](https://github.com/toddwschneider/nyc-taxi-data) for the post ["When Are Citi Bikes Faster Than Taxis in New York City?"](https://toddwschneider.com/posts/taxi-vs-citi-bike-nyc/)

This repo provides scripts to download, process, and analyze NYC's [Citi Bike share system data](https://www.citibikenyc.com/system-data). The data is stored in a [PostgreSQL](https://www.postgresql.org/) database, uses [PostGIS](https://postgis.net/) for spatial calculations, and [R](https://www.r-project.org/) for data analysis.

## Instructions

##### 1. Install [PostgreSQL](https://www.postgresql.org/download/) and [PostGIS](https://postgis.net/install)

Both are available via [Homebrew](https://brew.sh/) on Mac

##### 2. Download raw bike trips data

`./download_raw_data.sh`

##### 3. Initialize database and set up schema

`./initialize_database.sh`

##### 4. Import bike trips data into database and map to census tracts

`./import_trips.sh`

##### 5. Analysis

Additional Postgres and [R](https://www.r-project.org/) scripts for analysis are in the <code>analysis/</code> folder

## Other data sources

These are bundled with the repository, so no need to download separately, but:

- Shapefile for NYC census tracts and neighborhood tabulation areas comes from [NYC Planning](https://www.nyc.gov/site/planning/data-maps/open-data/districts-download-metadata.page)
- Central Park weather data comes from the [National Climatic Data Center](https://www.ncdc.noaa.gov/cdo-web/datasets/GHCND/stations/GHCND:USW00094728/detail)

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
