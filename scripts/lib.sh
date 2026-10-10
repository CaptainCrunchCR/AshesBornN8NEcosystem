# Shared helpers for backup.sh and restore.sh. Source it, don't run it.
# shellcheck shell=bash disable=SC2034

# Git Bash on Windows rewrites arguments that look like paths (/home/...);
# container paths must reach Docker untouched. No effect on Linux.
export MSYS_NO_PATHCONV=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$REPO_DIR/.env" ]; then
    echo "Missing $REPO_DIR/.env" >&2
    exit 1
fi
set -a
# shellcheck disable=SC1091
. "$REPO_DIR/.env"
set +a

BACKUP_DIR="${BACKUP_DIR:-$REPO_DIR/backups}"
RCLONE_IMAGE="rclone/rclone:1.75.2"
ALPINE_IMAGE="alpine:3.24.2"

POSTGRES_CONTAINER=ashesborn-postgres
N8N_CONTAINER=ashesborn-n8n
RUNNER_CONTAINER=ashesborn-n8n-runner
EVOLUTION_CONTAINER=ashesborn-evolution

# Volumes to archive: "container|path inside container|archive name".
VOLUME_ARCHIVES=(
    "$N8N_CONTAINER|/home/node/.n8n|n8n_storage"
    "$EVOLUTION_CONTAINER|/evolution/instances|evolution_instances"
)

log() { echo "$(date -u +%FT%TZ) $*"; }

# Databases to back up: every application database that is configured.
app_databases() {
    local db
    for db in "${POSTGRES_DB:-}" "${POSTGRES_EVOLUTION_DB:-}" "${POSTGRES_CHEETO_BOT_DB:-}"; do
        [ -n "$db" ] && echo "$db"
    done
}

# rclone against R2, configured entirely through environment variables so no
# config file or secret ever touches the disk or the command line.
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
export RCLONE_CONFIG_R2_ENDPOINT="${R2_ENDPOINT:-https://${R2_ACCOUNT_ID:-}.r2.cloudflarestorage.com}"
# The API token is scoped to one bucket and cannot create buckets.
export RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true

rclone_r2() {
    docker run --rm -i \
        -e RCLONE_CONFIG_R2_TYPE -e RCLONE_CONFIG_R2_PROVIDER \
        -e RCLONE_CONFIG_R2_ACCESS_KEY_ID -e RCLONE_CONFIG_R2_SECRET_ACCESS_KEY \
        -e RCLONE_CONFIG_R2_ENDPOINT -e RCLONE_CONFIG_R2_NO_CHECK_BUCKET \
        "$RCLONE_IMAGE" --log-level ERROR "$@"
}
