CREATE SCHEMA IF NOT EXISTS picidae;

-- GBIF.org (19 April 2023) GBIF Occurrence Download  https://doi.org/10.15468/dl.96kqtw
CREATE TABLE IF NOT EXISTS picidae.picidae
(
    "gbifID"                 text,
    "datasetKey"             text,
    "occurrenceID"           text,
    phylum                   text,
    class                    text,
    "order"                  text,
    family                   text,
    genus                    text,
    species                  text,
    "taxonRank"              text,
    "scientificName"         text,
    "verbatimScientificName" text,
    "countryCode"            text,
    "stateProvince"          text,
    "occurrenceStatus"       text,
    "individualCount"        integer,
    "publishingOrgKey"       text,
    "decimalLatitude"        numeric,
    "decimalLongitude"       numeric,
    elevation                text,
    "elevationAccuracy"      text,
    "eventDate"              timestamp,
    day                      integer,
    month                    integer,
    year                     integer,
    "taxonKey"               integer,
    "speciesKey"             integer,
    "institutionCode"        text,
    "collectionCode"         text,
    "catalogNumber"          text,
    "dateIdentified"         timestamp,
    license                  text,
    "recordedBy"             text,
    "lastInterpreted"        timestamp
);

SELECT COUNT(*) FROM picidae.picidae;

-- Create table of MA specific observations
CREATE TABLE IF NOT EXISTS picidae.ma_picidae AS
    SELECT * FROM picidae.picidae
    WHERE "stateProvince" = 'Massachusetts' AND
          "individualCount" IS NOT NULL; -- There are some null counts in older data

SELECT COUNT(*) FROM picidae.ma_picidae;

-- Create geom from lat and lon
ALTER TABLE picidae.ma_picidae
ADD COLUMN geom geometry(Point, 4326);
UPDATE picidae.ma_picidae
SET geom = ST_SetSRID(ST_MakePoint("decimalLongitude", "decimalLatitude"), 4326);

-- Total observations by species over all MA data
SELECT species, SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae
GROUP BY species
ORDER BY ma_observation_count DESC;

-- Total individual sightings
SELECT SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae;

-- Total observations species
SELECT COUNT(DISTINCT(species)) FROM picidae.ma_picidae;

-- MA observations by year
SELECT species, year, SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae
GROUP BY species, year
ORDER BY species, year DESC, ma_observation_count DESC;

-- 2021
SELECT species, year, SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae
WHERE year = 2021
GROUP BY species, year
ORDER BY ma_observation_count DESC;

CREATE TABLE picidae.ma_observations_2021 AS
    SELECT "gbifID", species, geom
    FROM picidae.ma_picidae
    WHERE year = 2021;

-- 2016
SELECT species, year, SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae
WHERE year = 2016
GROUP BY species, year
ORDER BY ma_observation_count DESC;

CREATE TABLE picidae.ma_observations_2016 AS
    SELECT "gbifID", species, geom
    FROM picidae.ma_picidae
    WHERE year = 2016;

-- 2011
SELECT species, year, SUM("individualCount") AS ma_observation_count
FROM picidae.ma_picidae
WHERE year = 2011
GROUP BY species, year
ORDER BY ma_observation_count DESC;

CREATE TABLE picidae.ma_observations_2011 AS
    SELECT "gbifID", species, geom
    FROM picidae.ma_picidae
    WHERE year = 2011;

-- MA statewide Tax parcel data https://www.mass.gov/info-details/massgis-data-property-tax-parcels
-- Merge east and west using QGIS "Merge vector layers" function, run "Fix geometries", then export to PostGreSQL
SELECT DISTINCT owner1 FROM picidae.ma_tax_parcels WHERE owner1 LIKE 'MASS%';

-- Mass Audubon owned tax parcels
CREATE TABLE picidae.ma_audubon_tax_parcels AS
    SELECT * FROM picidae.ma_tax_parcels
    WHERE owner1 IN ( -- 28 total
        'MASSACHUSETTE AUDUBON SOCIETY INC', 'MASSACHUSETTS AUDUBON', 'MASSACHUSETTS AUDUBON SOC',
        'MASSACHUSETTS AUDUBON SOCIETY', 'MASSACHUSETTS AUDUBON SOCIETY &', 'MASSACHUSETTS AUDUBON SOCIETY~',
        'MASSACHUSETTS  AUDUBON SOCIETY INC', 'MASSACHUSETTS  AUDUBON SOCIETY, INC.', 'MASSACHUSETTS AUDUBON SOCIETY INC',
        'MASSACHUSETTS AUDUBON SOCIETY, INC', 'MASSACHUSETTS AUDUBON SOCIETY, INC.', 'MASSACHUSETTS AUDUBON SOCIETY. INC',
        'MASSACHUSETTS AUDUBON SOC INC', 'MASS AUDUBON', 'MASS AUDUBON SOC', 'MASS AUDUBON SOCIETY', 'MASS AUDUBON SOCIETY~',
        'MASS  AUDUBON SOCIETY INC', 'MASS  AUDUBON SOCIETY, INC', 'MASS AUDUBON SOCIETY INC',
        'MASS AUDUBON SOCIETY INC.', 'MASS AUDUBON SOCIETY INC.~', 'MASS AUDUBON SOCIETY INC~', 'MASS AUDUBON SOCIETY, INC',
        'MASS AUDUBON SOCIETY, INC~', 'MASS AUDUBON SOCIETY,INC', 'MASS. AUDUBON SOCIETY INC.', 'THE MASSACHUSETTS AUDUBON SOCIETY, INC'
    );

-- Total Audubon parcels
SELECT COUNT(*) FROM picidae.ma_audubon_tax_parcels;

-- https://www.mass.gov/files/documents/2016/08/wr/classificationcodebook.pdf
SELECT use_code, COUNT(*) AS count
FROM picidae.ma_audubon_tax_parcels
GROUP BY use_code
ORDER BY count DESC;

-- DRUMLIN
-- Create tables with Drumlin Farm sightings
CREATE TABLE picidae.drumlin_parcels AS
    SELECT * FROM picidae.ma_audubon_tax_parcels
    WHERE id IN ('29002', '1834815', '1341910', '150277', '1074457', '329263', '1176926', '11615');

CREATE TABLE picidae.drumlin_poly AS
    SELECT ST_Transform(ST_Union(ST_SnapToGrid(drumlin_parcels.geom,0.0001)), 4326) AS geom
    FROM picidae.drumlin_parcels;

CREATE TABLE picidae.drumlin_sightings AS
    SELECT sightings.*
    FROM picidae.ma_picidae sightings, picidae.drumlin_poly
    WHERE ST_Contains(drumlin_poly.geom, sightings.geom);

SELECT SUM("individualCount") FROM picidae.drumlin_sightings;
SELECT year, SUM("individualCount") FROM picidae.drumlin_sightings
WHERE year IN (2011, 2016, 2021)
GROUP BY year;

CREATE TABLE picidae.drumlin_sightings_2011 AS
    SELECT *
    FROM picidae.drumlin_sightings
    WHERE year = 2011;

-- eBirders have a tendency to set a single lat/lon point as the spot for all
-- of their sightings
SELECT year, "recordedBy", COUNT(*) AS count, geom
FROM picidae.drumlin_sightings
WHERE year IN (2011, 2016, 2021)
GROUP BY year, "recordedBy", geom
ORDER BY count DESC;

-- One particular avid eBirder who tends to use the same coordinates
-- even over years
SELECT year, month, day, COUNT(*) AS count
FROM picidae.drumlin_sightings
WHERE "recordedBy" = 'obsr182792'
GROUP BY year, month, day
ORDER BY count DESC;

-- Tables with '_scatter' introduce a slight random scatter
-- to grouped points made by eBirders such as obsr182792
-- for better visualization than opacity changes allow.
CREATE TABLE picidae.drumlin_sightings_2011_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.drumlin_sightings_2011
    ) p;

CREATE TABLE picidae.drumlin_sightings_2016 AS
    SELECT *
    FROM picidae.drumlin_sightings
    WHERE year = 2016;

CREATE TABLE picidae.drumlin_sightings_2016_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.drumlin_sightings_2016
    ) p;

CREATE TABLE picidae.drumlin_sightings_2021 AS
    SELECT *
    FROM picidae.drumlin_sightings
    WHERE year = 2021;

CREATE TABLE picidae.drumlin_sightings_2021_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.drumlin_sightings_2021
    ) p;

-- BROADMOOR
-- Create tables with Broadmoor sightings
CREATE TABLE picidae.broadmoor_parcels AS
    SELECT * FROM picidae.ma_audubon_tax_parcels
    WHERE id IN ('1503037', '1513334', '1639238', '1642058', '1664149', '1854150',
                 '210095', '258769', '491756', '776869', '861119', '860992', '962742',
                 '928411', '990707', '1008127', '1192849', '1384812', '1461735');

CREATE TABLE picidae.broadmoor_poly AS
    SELECT ST_Transform(ST_Union(ST_SnapToGrid(broadmoor_parcels.geom,0.0001)), 4326) AS geom
    FROM picidae.broadmoor_parcels;

CREATE TABLE picidae.broadmoor_sightings AS
    SELECT sightings.*
    FROM picidae.ma_picidae sightings, picidae.broadmoor_poly
    WHERE ST_Contains(broadmoor_poly.geom, sightings.geom);

SELECT SUM("individualCount") FROM picidae.broadmoor_sightings;
SELECT year, SUM("individualCount") FROM picidae.broadmoor_sightings
WHERE year IN (2011, 2016, 2021)
GROUP BY year;

CREATE TABLE picidae.broadmoor_sightings_2011 AS
    SELECT *
    FROM picidae.broadmoor_sightings
    WHERE year = 2011;

CREATE TABLE picidae.broadmoor_sightings_2011_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.broadmoor_sightings_2011
    ) p;

CREATE TABLE picidae.broadmoor_sightings_2016 AS
    SELECT *
    FROM picidae.broadmoor_sightings
    WHERE year = 2016;

CREATE TABLE picidae.broadmoor_sightings_2016_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.broadmoor_sightings_2016
    ) p;

CREATE TABLE picidae.broadmoor_sightings_2021 AS
    SELECT *
    FROM picidae.broadmoor_sightings
    WHERE year = 2021;

CREATE TABLE picidae.broadmoor_sightings_2021_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.broadmoor_sightings_2021
    ) p;

-- IPSWICH
-- Create tables with Ipswich River sightings
CREATE TABLE picidae.ipswich_parcels AS
    SELECT * FROM picidae.ma_audubon_tax_parcels
    WHERE id IN ('1603240', '1854882', '18869', '84042', '101494',
                 '122788', '205595', '399165', '616390', '665829',
                 '727897', '761472', '813170', '945379', '976835',
                 '1067258', '1067020', '1245324', '1380486',
                 '1425174', '1450501', '1841709');

CREATE TABLE picidae.ipswich_poly AS
    SELECT ST_Transform(ST_Union(ST_SnapToGrid(ipswich_parcels.geom,0.0001)), 4326) AS geom
    FROM picidae.ipswich_parcels;

CREATE TABLE picidae.ipswich_sightings AS
    SELECT sightings.*
    FROM picidae.ma_picidae sightings, picidae.ipswich_poly
    WHERE ST_Contains(ipswich_poly.geom, sightings.geom);

SELECT SUM("individualCount") FROM picidae.ipswich_sightings;
SELECT year, SUM("individualCount") FROM picidae.ipswich_sightings
WHERE year IN (2011, 2016, 2021)
GROUP BY year;

CREATE TABLE picidae.ipswich_sightings_2011 AS
    SELECT *
    FROM picidae.ipswich_sightings
    WHERE year = 2011;

CREATE TABLE picidae.ipswich_sightings_2011_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.ipswich_sightings_2011
    ) p;

CREATE TABLE picidae.ipswich_sightings_2016 AS
    SELECT *
    FROM picidae.ipswich_sightings
    WHERE year = 2016;

CREATE TABLE picidae.ipswich_sightings_2016_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.ipswich_sightings_2016
    ) p;

CREATE TABLE picidae.ipswich_sightings_2021 AS
    SELECT *
    FROM picidae.ipswich_sightings
    WHERE year = 2021;

CREATE TABLE picidae.ipswich_sightings_2021_scatter AS
    SELECT ST_SetSRID(ST_MakePoint(
         ST_X(geom) + rad * SIND(ang),
         ST_Y(geom) + rad * COSD(ang)
       ), 4326) AS geom
    FROM (
        SELECT random() * 360.0 AS ang,
               random() * 0.00075 AS rad,
               geom
        FROM picidae.ipswich_sightings_2021
    ) p;