# 0007. Backup format and retention

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca
- **Refines:** [0004](0004-off-provider-backups-to-cloudflare-r2.md)

## Context

[ADR 0004](0004-off-provider-backups-to-cloudflare-r2.md) chose nightly backups to
Cloudflare R2 using `pg_dumpall`, keeping 30 days. Implementing it raised details that
change how backups are taken, kept and restored.

## Options considered

- **`pg_dumpall` (one SQL file for everything)** — simple, but restoring means replaying
  everything, including the admin role, onto a server where it already exists, and you
  cannot restore one application alone.
- **`pg_dump` per database (custom format) + roles separately** — each application can
  be restored on its own; `pg_restore` is faster and stricter.
- **Retention in the script** — needs delete logic and permissions in the script.
- **Retention as an R2 lifecycle rule** — Cloudflare deletes old objects itself; works
  even if the server is gone.

## Decision

- `scripts/backup.sh` writes, per run, `backups/<UTC timestamp>/` containing
  `globals.sql.gz` (roles), `db-<name>.dump` for each application database,
  `n8n_storage.tar.gz`, `evolution_instances.tar.gz` and `SHA256SUMS`. It then uploads
  them to `r2:<bucket>/<timestamp>/`.
- Data streams through `docker exec`/`docker run` stdin and stdout; the server only
  needs Docker. `rclone` runs in a container, configured only by environment variables.
- **R2 retention: a 30-day lifecycle rule on the bucket.** Locally, the newest 3 runs
  are kept for fast restores.
- `scripts/restore.sh <timestamp|latest>` verifies checksums, recreates each database
  and replaces the volumes, then restarts the services.
- An optional `BACKUP_HEALTHCHECK_URL` (for example healthchecks.io) is pinged on
  success and failure, so a silently failing backup gets noticed.

## Consequences

- Verified locally on 2026-10-10 with an S3-compatible stand-in for R2: backup, upload,
  download and restore brought back data in all three databases and the WhatsApp
  sessions volume.
- After a restore, every application database, including n8n's, is owned by the app
  user.
- The R2 lifecycle rule must be created by hand when the bucket is set up.
- Restore needs the same `.env` as the original server.

## Revisit if

- Backups grow large enough that full nightly copies become slow or expensive.
- A one-day data-loss window becomes unacceptable.
