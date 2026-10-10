#!/usr/bin/env bash
# Restore a backup made by backup.sh. DESTRUCTIVE: replaces the current databases
# and volumes with the backup's contents.
#
# Usage:
#   scripts/restore.sh latest          newest backup in R2
#   scripts/restore.sh <timestamp>     e.g. 2026-10-10T031500Z; uses backups/<timestamp>
#                                      locally if present, otherwise downloads it from R2
#   add --yes to skip the confirmation prompt
#
# Requires the stack to be up (docker compose up -d) with the same .env as when the
# backup was taken: N8N_ENCRYPTION_KEY must match, or n8n credentials are unreadable.
set -Eeuo pipefail
. "$(dirname "$0")/lib.sh"

STAMP="${1:-}"
CONFIRMED="${2:-}"
if [ -z "$STAMP" ]; then
    sed -n '2,12p' "$0"
    exit 1
fi

if [ "$STAMP" = latest ]; then
    STAMP="$(rclone_r2 lsf --dirs-only "r2:$R2_BUCKET" | sort | tail -n 1 | tr -d '/')"
    [ -n "$STAMP" ] || { log "no backups found in r2:$R2_BUCKET"; exit 1; }
    log "latest backup is $STAMP"
fi

SRC="$BACKUP_DIR/$STAMP"
if [ ! -d "$SRC" ]; then
    log "downloading $STAMP from R2"
    mkdir -p "$SRC"
    for name in $(rclone_r2 lsf "r2:$R2_BUCKET/$STAMP"); do
        rclone_r2 cat "r2:$R2_BUCKET/$STAMP/$name" > "$SRC/$name"
    done
fi

log "verifying checksums"
(cd "$SRC" && sha256sum -c --quiet SHA256SUMS)

if [ "$CONFIRMED" != --yes ]; then
    echo "This will REPLACE all current n8n, Evolution and Cheeto Bot data with backup $STAMP."
    read -r -p "Type 'restore' to continue: " answer
    [ "$answer" = restore ] || { echo "Aborted."; exit 1; }
fi

trap 'log "RESTORE FAILED: n8n, runner and Evolution are left stopped; fix the error and rerun"' ERR
log "stopping n8n, runner and Evolution"
docker stop "$RUNNER_CONTAINER" "$N8N_CONTAINER" "$EVOLUTION_CONTAINER" >/dev/null

for dump in "$SRC"/db-*.dump; do
    db="$(basename "$dump" .dump)"
    db="${db#db-}"
    log "restoring database $db"
    # Connect to the maintenance database: a database can't be dropped while connected to it.
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -q \
        -c "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE);" \
        -c "CREATE DATABASE \"$db\" OWNER \"$POSTGRES_NON_ROOT_USER\";"
    docker exec -i "$POSTGRES_CONTAINER" pg_restore -U "$POSTGRES_USER" -d "$db" --exit-on-error < "$dump"
done

for entry in "${VOLUME_ARCHIVES[@]}"; do
    IFS='|' read -r container path name <<< "$entry"
    log "restoring $name"
    docker run --rm -i --volumes-from "$container" "$ALPINE_IMAGE" \
        sh -c "find '$path' -mindepth 1 -delete && tar xzf - -C '$path'" < "$SRC/$name.tar.gz"
done

log "starting services"
docker start "$EVOLUTION_CONTAINER" "$N8N_CONTAINER" "$RUNNER_CONTAINER" >/dev/null
log "restore of $STAMP complete"
