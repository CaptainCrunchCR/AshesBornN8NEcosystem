# 0004. Back up off-provider to Cloudflare R2

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

When DigitalOcean removed the infrastructure, the data was lost with it, because nothing
was stored outside that account. Data worth protecting:

- **Postgres** — n8n workflows, credentials and executions; Evolution API data; the
  Cheeto Bot database.
- **`n8n_storage` volume** — n8n settings and its encryption key material.
- **`evolution_instances` volume** — WhatsApp sessions (without it, numbers must be
  re-paired).
- **`.env`** — secrets, including `N8N_ENCRYPTION_KEY`; without it, stored n8n
  credentials cannot be decrypted.

## Options considered

- **The hosting provider's own backups** — convenient, but lost along with the account,
  which is exactly the failure we suffered.
- **AWS S3** — reliable, but charges for downloads, which is costly during a restore.
- **Cloudflare R2** — S3-compatible; 10 GB free, then ~$0.015/GB-month; **no download
  fees**. The domain is already on Cloudflare.
- **Backblaze B2** — similar pricing; would add a third vendor.

## Decision

Run a nightly backup job on the server that dumps Postgres (`pg_dumpall`), archives the
`n8n_storage` and `evolution_instances` volumes, and uploads them to a Cloudflare R2
bucket. Keep 30 days of daily backups.

## Consequences

- Data survives loss of the server **and** of the hosting account.
- **Cloudflare billing must be independent of the hosting billing** (a different card, or
  at least billing alerts on both). Otherwise one payment problem could take out both.
- Restores must be tested periodically; an untested backup is not a backup.
- `.env` must also be kept safely outside the server (for example in a password manager),
  never in git.
- Expected cost: $0–1/month at current data size.

## Revisit if

- Backup size grows past what R2 pricing makes reasonable.
- Recovery needs a shorter data-loss window than one day.
