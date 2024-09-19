#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "netbox" <<-EOSQL
    -- Grant necessary privileges
    GRANT CONNECT ON DATABASE netbox TO postgres;
    GRANT USAGE ON SCHEMA public TO postgres;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO postgres;
    -- Grant schema creation and usage
    GRANT CREATE ON DATABASE netbox TO postgres;
    ALTER ROLE postgres SET search_path TO public;
    -- Make postgres the owner of the netbox database
    ALTER DATABASE netbox OWNER TO postgres;
EOSQL