# 0003. Expose services through Cloudflare Tunnel

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

`ashesborn.com` is managed in Cloudflare. Previously `n8n.ashesborn.com` and
`evolution.ashesborn.com` were DNS-only (grey cloud) A records pointing at the Droplet
IP `159.203.89.201`. Traefik listened publicly on ports 80/443 and obtained Let's Encrypt
certificates through the TLS-ALPN challenge.

Problems with that approach:

- The server's IP is public and its ports are open to scanners and attacks.
- Certificate issuance depends on the server being directly reachable; turning on
  Cloudflare's proxy (orange cloud) breaks it.
- Moving servers requires editing DNS records by hand.
- After the Droplet was deleted, the records kept pointing at an IP that DigitalOcean can
  reassign to another customer.

## Options considered

- **Keep Traefik + Let's Encrypt, DNS-only records** — known to work; exposes the server
  and keeps the issues above.
- **Traefik behind Cloudflare proxy with a DNS-01 challenge or origin certificate** —
  hides the IP, but ports stay open and the setup is more complex.
- **Cloudflare Tunnel (`cloudflared`)** — an outbound-only connection from the server to
  Cloudflare; Cloudflare handles HTTPS. Free.

## Decision

Run a `cloudflared` container in the Compose stack and route `n8n.ashesborn.com` and
`evolution.ashesborn.com` through a Cloudflare Tunnel straight to the containers on the
internal Docker network. **Traefik and Let's Encrypt are removed** because they are no
longer needed.

## Consequences

- The server needs **no inbound ports** except SSH; the firewall can block 80/443.
- The server IP is never published in DNS; moving servers means starting the stack
  elsewhere — DNS does not change.
- Cloudflare provides TLS and bot/DDoS protection.
- New dependency on Cloudflare availability. The domain already depends on Cloudflare,
  so the added risk is small.
- The tunnel token is a secret and goes in `.env`.
- **Immediate action:** remove or neutralize the stale A records pointing at
  `159.203.89.201`.
- WhatsApp/Evolution webhooks and n8n's `WEBHOOK_URL` keep the same hostnames.

## Revisit if

- Cloudflare Tunnel limits (request size, timeouts, websocket behaviour) affect n8n or
  Evolution.
- The domain moves away from Cloudflare.
