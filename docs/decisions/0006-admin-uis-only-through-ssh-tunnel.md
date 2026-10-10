# 0006. Admin UIs reachable only through an SSH tunnel

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

pgAdmin (Postgres) and RedisInsight (Redis) had no Traefik labels and no published
ports, so they ran but nobody could open them. These tools give full control over all
data, so they must not be publicly reachable.

## Options considered

- **Publish them through the Cloudflare Tunnel behind Cloudflare Access** — convenient
  browser access with Cloudflare login; more Cloudflare configuration, and a mistake in
  the Access policy exposes the database.
- **Bind them to the server's localhost and use an SSH tunnel** — nothing new exposed;
  only people with SSH access to the server can reach them.
- **Remove them** — saves ~0.5 GB RAM; lose convenient admin tools.

## Decision

Publish pgAdmin on `127.0.0.1:5050` and RedisInsight on `127.0.0.1:5540` of the server
only. To use them, open an SSH tunnel from your computer:

```bash
ssh -L 5050:127.0.0.1:5050 -L 5540:127.0.0.1:5540 user@server
```

Then browse to `http://localhost:5050` (pgAdmin) or `http://localhost:5540`
(RedisInsight). Inside them, connect to hosts `postgres:5432` and `redis:6379`.

## Consequences

- No extra public attack surface; access is as secure as SSH.
- Requires an SSH client and key on the admin's computer.
- RedisInsight has no login of its own; the SSH tunnel is its only protection.

## Revisit if

Several non-technical people need admin access (then consider Cloudflare Access).
