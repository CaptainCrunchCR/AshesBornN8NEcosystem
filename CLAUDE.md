# AshesBorn n8n Ecosystem

Docker Compose infrastructure for a self-hosted n8n + Evolution API (WhatsApp) stack on
`ashesborn.com`. The root `docker-compose.yml` includes one compose file per service from
`project/<service>/`; all services read the root `.env` (gitignored).

Docs: `docs/deployment.md` (production setup on Linode), `README.md` (layout, local run).

## Verifying changes

- `docker compose config --quiet` validates the compose files (needs a `.env`; copy
  `.env.example` temporarily and delete it afterwards — never commit `.env`).
- For behaviour changes, boot the stack locally with `compose.local.yml` under a
  throwaway project name (`docker compose -p ab-smoke ...`), check logs and health
  endpoints, then `down -v`.
- Backup/restore changes: test end to end against a local S3 stand-in
  (`rclone serve s3`) with `R2_ENDPOINT` pointing at it.

## Decision records

Every significant decision is recorded as an ADR in `docs/decisions/` — read the index
in `docs/decisions/README.md` before changing infrastructure.

- When a change alters hosting, networking, security, backups, data handling or adds or
  removes a service, write a new ADR from `docs/decisions/template.md` in the same change
  and add it to the index.
- Never rewrite an accepted ADR; supersede it with a new one and update the old one's
  status line only.
- Record the date that prices, policies and other external facts were checked.
