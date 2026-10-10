# AshesBorn n8n Ecosystem

Self-hosted automation stack for `ashesborn.com`: **n8n** workflows connected to
WhatsApp through **Evolution API**, running with Docker Compose on a single server.

```
Internet ──► Cloudflare ──(tunnel)──► cloudflared ──► n8n ◄──► n8n runner
                                                 └──► Evolution API (WhatsApp)
                                                         │
                                      Postgres ◄─────────┴──► Redis
                                         │
                       nightly backup ───┴──► Cloudflare R2
```

| Service | Purpose |
|---|---|
| `cloudflared` | Cloudflare Tunnel; publishes n8n and Evolution without opening ports |
| `n8n` + `n8n-runner` | Workflow engine; the runner executes Code-node tasks |
| `evolution` | WhatsApp API gateway |
| `postgres` | Databases for n8n, Evolution and Cheeto Bot |
| `redis` | Cache for Evolution |
| `pgadmin`, `redisinsight` | Admin UIs, reachable only through SSH |

## Documentation

- **[Deployment guide](docs/deployment.md)**: setting up the production server on Linode.
- **[Decision records](docs/decisions/README.md)**: why everything is built this way.

## Repository layout

```
docker-compose.yml      includes one compose file per service from project/
compose.local.yml       overrides for running on your own computer
project/<service>/      compose file for each service
init-data.sh            creates the app user and databases on first Postgres start
scripts/backup.sh       backup to Cloudflare R2
scripts/restore.sh      restore from a backup
.env.example            every configuration variable, documented
```

## Running locally

Requires Docker Desktop.

```bash
cp .env.example .env    # fill in the change-me values; R2 and tunnel values can stay dummy
docker compose -f docker-compose.yml -f compose.local.yml up -d postgres redis n8n n8n-runner evolution
```

- n8n: <http://localhost:5678>
- Evolution API: <http://localhost:8080>

Stop with `docker compose -f docker-compose.yml -f compose.local.yml down`. Add `-v` to
also delete the local data.
