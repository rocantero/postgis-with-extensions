\set VERBOSITY verbose
\set ON_ERROR_STOP on

CREATE DATABASE test;
\c test


SELECT * FROM pg_available_extensions;


CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;


-- https://github.com/citusdata/pg_cron
CREATE EXTENSION pg_cron;
SELECT cron.schedule('nightly-vacuum', '0 3 * * *', 'VACUUM');
SELECT cron.unschedule('nightly-vacuum');


-- https://github.com/postgis/postgis
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
-- CREATE EXTENSION IF NOT EXISTS postgis_raster;  -- Unavailable in postgis 2.5
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;
CREATE EXTENSION IF NOT EXISTS address_standardizer;


-- https://github.com/pgaudit/pgaudit
CREATE EXTENSION IF NOT EXISTS pgaudit;
SET pgaudit.log = 'all, -misc';
SET pgaudit.log_level = notice;


-- https://github.com/HypoPG/hypopg
CREATE EXTENSION IF NOT EXISTS hypopg;

CREATE TABLE hypo AS SELECT id, 'line ' || id AS val FROM generate_series(1,10000) id;
EXPLAIN SELECT * FROM hypo WHERE id = 1;

SELECT * FROM hypopg_create_index('CREATE INDEX ON hypo (id)');
EXPLAIN SELECT * FROM hypo WHERE id = 1;

DROP TABLE hypo;


-- https://github.com/powa-team/pg_qualstats
CREATE EXTENSION IF NOT EXISTS pg_qualstats;
SELECT * FROM pg_qualstats;


-- https://github.com/powa-team/pg_stat_kcache
CREATE EXTENSION IF NOT EXISTS pg_stat_kcache;
SELECT * FROM pg_stat_kcache();


-- https://github.com/rjuju/pg_track_settings
CREATE EXTENSION IF NOT EXISTS pg_track_settings;
SELECT pg_track_settings_snapshot();


-- https://github.com/postgrespro/pg_wait_sampling
CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;
WITH t as (SELECT sum(0) FROM pg_wait_sampling_current)
	SELECT sum(0) FROM generate_series(1, 2), t;


-- https://github.com/powa-team/powa-archivist
CREATE EXTENSION IF NOT EXISTS powa;
SELECT * FROM powa_functions ORDER BY module, operation;
