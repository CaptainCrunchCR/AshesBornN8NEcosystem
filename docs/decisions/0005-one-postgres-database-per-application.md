# 0005. One Postgres database per application

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Pablo Fonseca

## Context

A single Postgres server serves n8n, Evolution API and the Cheeto Bot. The original
`init-data.sh` created the n8n database and a Cheeto Bot database, but:

- The Cheeto Bot step connected to the wrong database, so its `GRANT CREATE ON SCHEMA
  public` did not apply to the new database. On Postgres 15+ the app user could not
  create tables there.
- Evolution API had no database of its own defined in the repo.
- The script had Windows line endings in the repo, which makes it fail inside the
  Linux container.

## Options considered

- **One shared database** — fewer moving parts, but applications' tables and migrations
  mix, and one app's problem can affect the others.
- **One database per application, owned by the app user** — clean separation, each
  can be dumped or restored on its own, and ownership grants all needed permissions.
- **A separate Postgres user per application** — stronger isolation, but more secrets
  to manage for little benefit at this scale.

## Decision

Each application gets its own database, created by `init-data.sh` on first start and
**owned by the shared non-root app user** (`POSTGRES_NON_ROOT_USER`):

| Database | Variable | Used by |
|---|---|---|
| `POSTGRES_DB` | already existed | n8n |
| `POSTGRES_EVOLUTION_DB` | new | Evolution API (`DATABASE_CONNECTION_URI`) |
| `POSTGRES_CHEETO_BOT_DB` | already existed | Cheeto Bot |

A `.gitattributes` file now forces LF line endings for the whole repo.

## Consequences

- `init-data.sh` only runs when the `postgres_data` volume is empty. Adding a database
  to an existing server must be done by hand (`CREATE DATABASE x OWNER app_user;`).
- All apps still share one Postgres user and server. A compromised app could read the
  others' data.
- Passwords in `.env` must not contain single quotes, because the script embeds them in
  SQL.

## Revisit if

- An application needs stronger isolation (then give it its own user).
- Load requires splitting databases across servers.
