# 0002. Host the stack on Akamai Cloud (Linode)

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

The Docker Compose stack (Traefik, n8n, n8n runner, Evolution API, Postgres, Redis,
pgAdmin, RedisInsight) ran on a single DigitalOcean Droplet. After a payment issue,
DigitalOcean removed all of the infrastructure.

Goals for the new home, in priority order:

1. **Price transparency** — a predictable monthly bill.
2. **Better support than DigitalOcean.**
3. **Solid** — an established provider with a tolerant non-payment process.

Sizing: the stack needs roughly **8 GB RAM** to run comfortably (4 GB only if the admin
UIs are dropped).

## Options considered

Prices and policies as checked on 2026-10-10 (mostly from provider pages; some from
third-party trackers).

| Option | ~Cost/mo (8 GB) | Support | On non-payment | Notes |
|---|---|---|---|---|
| **Akamai Linode** Shared 8 GB | **$48 flat** (4 vCPU, 160 GB, 5 TB) | **24/7 phone + ticket, free** | Powered off first; deleted servers kept as images ~90 days (per Linode staff) | Owned by Akamai |
| Vultr Regular 8 GB | ~$40 | Ticket; weaker reviews | No published grace period; a report of deletion over a $10 balance | |
| Hetzner CX33 | €8.99 | Ticket only, slower in English | Strict with new accounts | EU only; US plans ~3× after June 2026; strict sign-up verification |
| OVHcloud VPS | ~$8–10 | Many 2026 complaints; good support from $300/mo | Not documented | Unlimited traffic |
| AWS Lightsail 8 GB | $44 (2 vCPU) | Engineers need a $29+/mo plan | 30 days to reactivate | Best option if AWS is required |
| AWS EC2 / GCP / Azure | ~$56–60 + $29 support ≈ $85–90 | Paid plans only | AWS: 30 days | Many separately metered line items |
| Railway / Fly.io | Usage-based (~$40–70, varies) | Weak on low tiers | — | Unpredictable bill; Compose import limited |
| Render | ~$110+ | — | — | One priced service per container |
| Supabase / n8n Cloud | — | — | — | Cannot run the whole stack |

## Decision

Host the stack on **Akamai Cloud (Linode), Shared CPU 8 GB plan ($48/month)**, as a
single server running Docker Compose.

It is the only option that meets all three goals: one flat price that includes disk,
traffic and IP; free 24/7 human support including phone; and a non-payment process that
powers servers off before deleting them, backed by a large established company.

## Consequences

- The ~90-day image retention is based on Linode staff forum answers, not a written
  policy. It is a safety net, **not** a backup strategy — see [0004](0004-off-provider-backups-to-cloudflare-r2.md).
- Single server = single point of failure. Acceptable for current scale.
- We pay ~$8/mo more than Vultr and far more than Hetzner EU in exchange for support and
  predictability.
- Keep a backup payment method on the account and enable billing alerts.

## Revisit if

- Linode raises prices significantly or changes its support or non-payment policies.
- The stack outgrows one 8 GB server.
- The team needs to be on AWS (then use Lightsail).
