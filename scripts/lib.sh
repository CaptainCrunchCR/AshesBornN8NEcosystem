# Shared helpers for backup.sh and restore.sh. Source it, don't run it.
# shellcheck shell=bash disable=SC2034

# Git Bash on Windows rewrites arguments that look like paths (/home/...);
# container paths must reach Docker untouched. No effect on Linux.
export MSYS_NO_PATHCONV=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Missing $ENV_FILE" >&2
    exit 1
fi

# Read one KEY=value from .env without sourcing the whole file, so values with
# spaces or special characters elsewhere in it can't break the scripts.
env_get() {
    local value
    value="$(grep -m 1 -E "^$1=" "$ENV_FILE" | cut -d= -f2- | tr -d '\r')" || true
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    printf '%s' "${value:-${2:-}}"
}

POSTGRES_USER="$(env_get POSTGRES_USER)"
R2_ACCOUNT_ID="$(env_get R2_ACCOUNT_ID)"
R2_BUCKET="$(env_get R2_BUCKET)"
BACKUP_HEALTHCHECK_URL="${BACKUP_HEALTHCHECK_URL:-$(env_get BACKUP_HEALTHCHECK_URL)}"
BACKUP_DIR="${BACKUP_DIR:-$(env_get BACKUP_DIR "$REPO_DIR/backups")}"

RCLONE_IMAGE="rclone/rclone:1.75.2"
ALPINE_IMAGE="alpine:3.24.2"

POSTGRES_CONTAINER=dialogato-postgres
N8N_CONTAINER=dialogato-n8n
RUNNER_CONTAINER=dialogato-n8n-runner
EVOLUTION_CONTAINER=dialogato-evolution

# Volumes to archive: "container|path inside container|archive name".
VOLUME_ARCHIVES=(
    "$N8N_CONTAINER|/home/node/.n8n|n8n_storage"
    "$EVOLUTION_CONTAINER|/evolution/instances|evolution_instances"
)

log() { echo "$(date -u +%FT%TZ) $*"; }

# No -i: inside "while read ... < file" loops, a forwarded stdin would swallow the
# rest of the file.
psql_admin() {
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 "$@"
}

# rclone against R2 (or any S3-compatible storage), configured only through
# environment variables so secrets never touch the disk or the command line.
RCLONE_CONFIG_R2_TYPE=s3
RCLONE_CONFIG_R2_PROVIDER="$(env_get R2_PROVIDER Cloudflare)"
RCLONE_CONFIG_R2_ACCESS_KEY_ID="$(env_get R2_ACCESS_KEY_ID)"
RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$(env_get R2_SECRET_ACCESS_KEY)"
RCLONE_CONFIG_R2_ENDPOINT="$(env_get R2_ENDPOINT "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com")"
# The API token is scoped to one bucket and cannot create buckets.
RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true
export RCLONE_CONFIG_R2_TYPE RCLONE_CONFIG_R2_PROVIDER RCLONE_CONFIG_R2_ACCESS_KEY_ID \
    RCLONE_CONFIG_R2_SECRET_ACCESS_KEY RCLONE_CONFIG_R2_ENDPOINT RCLONE_CONFIG_R2_NO_CHECK_BUCKET

rclone_r2() {
    docker run --rm -i \
        -e RCLONE_CONFIG_R2_TYPE -e RCLONE_CONFIG_R2_PROVIDER \
        -e RCLONE_CONFIG_R2_ACCESS_KEY_ID -e RCLONE_CONFIG_R2_SECRET_ACCESS_KEY \
        -e RCLONE_CONFIG_R2_ENDPOINT -e RCLONE_CONFIG_R2_NO_CHECK_BUCKET \
        "$RCLONE_IMAGE" --log-level ERROR "$@"
}
