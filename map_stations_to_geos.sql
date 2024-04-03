UPDATE stations
SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

UPDATE stations
SET nyct2010_gid = n.gid,
    boroname = n.boroname,
    ntacode = n.ntacode,
    ntaname = n.ntaname
FROM nyct2010 n
WHERE ST_Within(stations.geom, n.geom);

UPDATE stations
SET taxi_zone_gid = z.gid,
    taxi_zone_name = z.zone
FROM taxi_zones z
WHERE ST_Within(stations.geom, z.geom);
