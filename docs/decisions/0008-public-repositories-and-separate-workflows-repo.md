# 0008. Public repositories, with workflows in their own repo

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

All n8n workflows were lost with the DigitalOcean server and will be rebuilt from
scratch. They need version history, review, and a way for Claude to create and edit
them as files. The infrastructure repository was private. The owner decided to make
both the infrastructure and the workflows repositories public.

## Options considered

- **Workflows inside this repository** — one place, but workflow changes (frequent) mix
  with infrastructure changes (rare), and the two have different review rhythms.
- **Separate workflows repository** — independent history; it can target any n8n
  instance (local or production) through n8n's API.
- **n8n's built-in Git source control** — an Enterprise feature; not available on the
  free self-hosted edition.
- **Private vs public** — private hides details; public makes the work shareable and
  lets the production server clone without credentials.

## Decision

- Workflows live in a separate public repository,
  [`CaptainCrunchCR/AshesBornN8NWorkflow`](https://github.com/CaptainCrunchCR/AshesBornN8NWorkflow),
  starting empty.
- This infrastructure repository becomes **public**.
- The original DigitalOcean-era configuration is kept unchanged on the branch
  `backup/original-droplet-setup`.

## Consequences

- **Nothing secret may ever be committed** to either repository. History is permanent
  and public: a leaked secret must be rotated, not just deleted.
  - Infrastructure: secrets only in `.env` (gitignored); `.env.example` holds
    placeholders only. The full history was scanned with gitleaks before going public.
  - Workflows: n8n exports reference credentials only by name and ID, never the secret
    values. **Pinned test data must be stripped** before committing, since it can contain
    real WhatsApp messages and phone numbers.
- Anyone can read the architecture. Security must not rely on it being hidden; it relies
  on no open ports, SSH keys, and secrets kept out of git.
- Commit author email addresses are publicly visible.
- The production server clones over HTTPS without a deploy key.

## Revisit if

- The workflows start to contain business logic or data that should not be public; then
  make the workflows repository private.
