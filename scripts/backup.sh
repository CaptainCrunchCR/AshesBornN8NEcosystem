#!/usr/bin/env bash
# Back up the AshesBorn stack and upload it to Cloudflare R2 (ADR 0004).
#
# Creates backups/<timestamp>/ with:
#   globals.sql.gz          Postgres roles
#   db-<name>.dump          one pg_dump (custom format) per application database
#   <volume>.tar.gz         n8n storage and Evolution WhatsApp sessions
#   SHA256SUMS
#
# Environment overrides:
#   SKIP_UPLOAD=1             keep the backup local only (for testing)
#   BACKUP_KEEP_LOCAL=3       local copies to keep; R2 retention is a bucket lifecycle rule
#   BACKUP_HEALTHCHECK_URL    optional; pinged on success, "<url>/fail" on failure
#
# Server cron entry (see docs/deployment.md):
#   15 3 * * * /opt/ashesborn/scripts/backup.sh >> /var/log/ashesborn-backup.log 2>&1
set -Eeuo pipefail
. "$(dirname "$0")/lib.sh"

KEEP_LOCAL="${BACKUP_KEEP_LOCAL:-3}"
STAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT="$BACKUP_DIR/$STAMP"

notify() {
    [ -n "${BACKUP_HEALTHCHECK_URL:-}" ] || return 0
    curl -fsS -m 10 --retry 3 "${BACKUP_HEALTHCHECK_URL}$1" >/dev/null || true
}
trap 'log "BACKUP FAILED"; notify /fail' ERR

mkdir -p "$OUT"

log "dumping Postgres roles"
docker exec "$POSTGRES_CONTAINER" pg_dumpall -U "$POSTGRES_USER" --globals-only \
    | gzip > "$OUT/globals.sql.gz"

for db in $(app_databases); do
    log "dumping database $db"
    docker exec "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" -Fc "$db" > "$OUT/db-$db.dump"
done

for entry in "${VOLUME_ARCHIVES[@]}"; do
    IFS='|' read -r container path name <<< "$entry"
    log "archiving $name"
    docker run --rm --volumes-from "$container:ro" "$ALPINE_IMAGE" \
        tar czf - -C "$path" . > "$OUT/$name.tar.gz"
done

(cd "$OUT" && sha256sum -- * > SHA256SUMS)
log "backup written to $OUT ($(du -sh "$OUT" | cut -f1))"

if [ "${SKIP_UPLOAD:-0}" = 1 ]; then
    log "SKIP_UPLOAD=1: not uploading"
else
    for file in "$OUT"/*; do
        log "uploading $(basename "$file")"
        rclone_r2 rcat "r2:$R2_BUCKET/$STAMP/$(basename "$file")" < "$file"
    done
    log "uploaded to r2:$R2_BUCKET/$STAMP"
fi

# Keep only the newest local copies.
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort | head -n -"$KEEP_LOCAL" \
    | while read -r old; do log "removing old local backup $(basename "$old")"; rm -rf -- "$old"; done

notify ""
log "backup complete"
