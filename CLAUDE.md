# AshesBorn n8n Ecosystem

Docker Compose infrastructure for a self-hosted n8n + Evolution API (WhatsApp) stack on
`ashesborn.com`. The root `docker-compose.yml` includes one compose file per service from
`project/<service>/`; all services read the root `.env` (gitignored).

## Decision records

Every significant decision is recorded as an ADR in `docs/decisions/` — read the index
in `docs/decisions/README.md` before changing infrastructure.

- When a change alters hosting, networking, security, backups, data handling or adds or
  removes a service, write a new ADR from `docs/decisions/template.md` in the same change
  and add it to the index.
- Never rewrite an accepted ADR; supersede it with a new one and update the old one's
  status line only.
- Record the date that prices, policies and other external facts were checked.
