# Architecture Decision Records

This folder records **why** the AshesBorn n8n ecosystem is built the way it is.
Each significant decision gets one short, numbered file (an ADR).

## Index

| # | Decision | Status | Date |
|---|----------|--------|------|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-10-10 |
| [0002](0002-host-on-akamai-linode.md) | Host the stack on Akamai Cloud (Linode) | Accepted | 2026-10-10 |
| [0003](0003-expose-services-via-cloudflare-tunnel.md) | Expose services through Cloudflare Tunnel | Accepted | 2026-10-10 |
| [0004](0004-off-provider-backups-to-cloudflare-r2.md) | Back up off-provider to Cloudflare R2 | Accepted | 2026-10-10 |
| [0005](0005-one-postgres-database-per-application.md) | One Postgres database per application | Accepted | 2026-10-10 |

## How to add one

1. Copy [`template.md`](template.md) to `NNNN-short-title.md` using the next number.
2. Fill it in. Keep it short — the goal is that someone a year from now understands
   the *why*, not every detail.
3. Add a row to the index above.

## Rules

- **ADRs are never rewritten after acceptance.** If a decision changes, write a new ADR
  and set the old one's status to `Superseded by [NNNN](...)`. The history is the point.
- Statuses: `Proposed`, `Accepted`, `Rejected`, `Deprecated`, `Superseded by NNNN`.
- Record facts that drove the decision (prices, policies, incidents) with the date
  they were checked, since they go stale.
