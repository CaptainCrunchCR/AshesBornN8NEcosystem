# 0001. Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

The stack was previously lost when DigitalOcean removed the infrastructure after a
payment issue. Rebuilding it involves several choices (provider, networking, backups)
whose reasoning would otherwise live only in chat history and memory, and be lost.

## Options considered

- **Nothing written down** — fastest now, but reasons get forgotten and decisions get
  re-argued.
- **A wiki or external doc** — easy to edit, but drifts away from the code it describes.
- **ADRs in the repository** — Markdown files versioned alongside the code; every change
  to a decision is visible in git history.

## Decision

Keep Architecture Decision Records in `docs/decisions/`, one numbered file per
significant decision, following [`template.md`](template.md).

## Consequences

- Any change that alters infrastructure, providers, security posture or data handling
  should come with a new or superseding ADR.
- Accepted ADRs are not edited; they are superseded, so the history remains readable.

## Revisit if

The records stop being maintained or the team adopts another documentation system.
