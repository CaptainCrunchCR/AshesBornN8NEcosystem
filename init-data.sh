#!/bin/bash
# Runs once, when Postgres starts with an empty postgres_data volume.
set -euo pipefail

if [ -z "${POSTGRES_NON_ROOT_USER:-}" ] || [ -z "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
    echo "SETUP INFO: POSTGRES_NON_ROOT_USER/PASSWORD not set; skipping app user and databases."
    exit 0
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER "${POSTGRES_NON_ROOT_USER}" WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE "${POSTGRES_DB}" TO "${POSTGRES_NON_ROOT_USER}";
    GRANT CREATE ON SCHEMA public TO "${POSTGRES_NON_ROOT_USER}";
EOSQL

# Each application gets its own database, owned by the app user so it can create
# tables and schemas in it (Postgres 15+ no longer allows that on public by default).
for db in "${POSTGRES_EVOLUTION_DB:-}" "${POSTGRES_CHEETO_BOT_DB:-}"; do
    if [ -n "$db" ]; then
        echo "SETUP INFO: creating database ${db}"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
            -c "CREATE DATABASE \"${db}\" OWNER \"${POSTGRES_NON_ROOT_USER}\";"
    fi
done
