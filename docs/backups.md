# Backups

Full coverage uses two independent layers. Each one covers what the other cannot.

| Layer | Protects against | Where |
|---|---|---|
| **Provider backups** (e.g. DigitalOcean Droplet backups or snapshots) | A broken server or a bad update; restores the whole machine quickly | Inside the hosting provider's account |
| **Off-provider backups** (`scripts/backup.sh`) | **Losing the hosting account itself**, or moving to another provider | Cloudflare R2, a different company billed separately |

Provider backups are lost together with the account, so the off-provider layer is
the one that counts in the worst case.

## What is backed up

`scripts/backup.sh` creates `backups/<UTC timestamp>/` and uploads it to R2:

| File | Contents |
|---|---|
| `db-<name>.dump` | Every Postgres database (n8n, Evolution, Dialogato, …), discovered automatically |
| `databases.txt` | Each database's owner, used to recreate it on restore |
| `globals.sql.gz` | Postgres roles, for reference |
| `n8n_storage.tar.gz` | n8n's data volume |
| `evolution_instances.tar.gz` | WhatsApp sessions; without it every number must be re-paired |
| `SHA256SUMS` | Checksums, verified before any restore |

**Not in the backup: `.env`.** It holds every password and `N8N_ENCRYPTION_KEY`, without
which stored n8n credentials cannot be decrypted. Keep a copy in a password manager.

The server only needs Docker: database dumps and archives stream through `docker exec`,
and `rclone` runs in a container.

## One-time setup

### 1. Cloudflare R2 bucket

Use a **different payment card** for Cloudflare than for the hosting provider, so one
failed payment can't take out both the server and its backups.

1. Cloudflare dashboard → **R2 Object Storage** → **Create bucket** → `dialogato-backups`.
2. In the bucket → **Settings → Object lifecycle rules** → add a rule for all objects:
   **delete 30 days after upload**. This is the retention policy; the script never
   deletes from R2.
3. **R2 → Manage API tokens** → **Create API token**: **Object Read & Write**, applied
   to the `dialogato-backups` bucket only.

### 2. Add to `.env` on the server

```
R2_ACCOUNT_ID=<Cloudflare account ID, on the R2 overview page>
R2_ACCESS_KEY_ID=<from the API token>
R2_SECRET_ACCESS_KEY=<from the API token>
R2_BUCKET=dialogato-backups
# Optional, recommended: a free check at https://healthchecks.io with a daily schedule.
# You get an email if a backup fails or doesn't run.
BACKUP_HEALTHCHECK_URL=https://hc-ping.com/<uuid>
```

Any S3-compatible storage works instead of R2 by also setting `R2_ENDPOINT` (and
`R2_PROVIDER` to the matching rclone provider name).

### 3. First run and schedule

```bash
./scripts/backup.sh
```

It should end with `backup complete`, and the files should appear in the bucket. Then
schedule it nightly with `crontab -e` (adjust the path to where the repo lives):

```cron
15 3 * * * /opt/dialogato/scripts/backup.sh >> /var/log/dialogato-backup.log 2>&1
```

The log file must be writable by the user that owns the crontab.

## Restoring

```bash
./scripts/restore.sh latest            # newest backup in R2
./scripts/restore.sh 2026-10-11T031500Z
```

It verifies the checksums, lists what it will replace and asks you to type `restore`.
It then stops n8n, the runner and Evolution, recreates each database, replaces the
two volumes and starts the services again.

The stack must be running with the **same `.env`** as when the backup was taken.

**To rebuild on a new server** (any provider): install Docker, clone this repo, put
the saved `.env` in place, `docker compose up -d`, point the DNS records at the new
server, then `./scripts/restore.sh latest`.

## Keep it honest

- **Test a restore every few months.** A backup that has never been restored is not proven.
- Watch the healthchecks.io emails; a backup that silently stopped is the common failure.
- Nightly backups mean losing at most about one day of data.
