-- Initialize pg_lake extensions
CREATE EXTENSION IF NOT EXISTS pg_lake CASCADE;

-- Set default S3 location for Iceberg tables
SET pg_lake_iceberg.default_location_prefix TO 's3://dash-iceberg-snowflake/demos/pg_lake/';
