#!/bin/bash
set -e;

if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
        GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
EOSQL
else
    echo "SETUP INFO: No Environment variables given!"
fi

# Owned by the app user, so it can create tables (Postgres 15+ no longer allows that
# on another owner's public schema).
if [ -n "${POSTGRES_DIALOGATO_DB:-}" ] && [ -n "${POSTGRES_NON_ROOT_USER:-}" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE ${POSTGRES_DIALOGATO_DB} OWNER ${POSTGRES_NON_ROOT_USER};
EOSQL
else
    echo "SETUP INFO: No Dialogato database variable given!"
fi
