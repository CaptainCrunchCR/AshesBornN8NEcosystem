# Deploying to Akamai Linode

Step-by-step setup of the production server. The *why* behind each choice is in
[`decisions/`](decisions/README.md). Do the steps in order; each takes a few minutes.

**You will end up with:** one Linode server with no public web ports, running the stack
with Docker Compose; `n8n.ashesborn.com` and `evolution.ashesborn.com` served through a
Cloudflare Tunnel; nightly backups in Cloudflare R2.

---

## 0. Billing safety first

The previous server was lost to a payment problem. Before creating anything:

- [ ] Add a **backup payment method** to the Akamai/Linode account.
- [ ] Turn on billing/usage email notifications in both Akamai and Cloudflare where available.
- [ ] Use a **different card** for Cloudflare (R2) than for Linode, so one failed card can't
      take out both the server and its backups ([ADR 0004](decisions/0004-off-provider-backups-to-cloudflare-r2.md)).

## 1. Cloudflare: remove the stale DNS records

`n8n.ashesborn.com` and `evolution.ashesborn.com` still point at `159.203.89.201`, the
deleted DigitalOcean server. That IP can be reassigned to someone else.

- [ ] Cloudflare dashboard → `ashesborn.com` → **DNS → Records** → delete both A records.
      The tunnel recreates them as CNAMEs in step 3.

## 2. Cloudflare R2: backup bucket

- [ ] **R2 Object Storage** → **Create bucket** → name `ashesborn-backups`, location
      automatic.
- [ ] In the bucket → **Settings → Object lifecycle rules** → **Add rule**: apply to all
      objects, **delete objects 30 days after upload**
      ([ADR 0007](decisions/0007-backup-format-and-retention.md)).
- [ ] **R2 → Manage API tokens** → **Create API token**: permission **Object Read & Write**,
      **apply to the `ashesborn-backups` bucket only**.
- [ ] Note the **Access Key ID**, **Secret Access Key** and your **Account ID** (shown on
      the R2 overview page). They go into `.env` as `R2_ACCESS_KEY_ID`,
      `R2_SECRET_ACCESS_KEY` and `R2_ACCOUNT_ID`.

## 3. Cloudflare Tunnel

- [ ] **Zero Trust** → **Networks → Tunnels** → **Create a tunnel** → type **Cloudflared**
      → name `ashesborn`.
- [ ] On the install screen, choose **Docker**. Copy only the token: the long string after
      `--token`. It goes into `.env` as `CLOUDFLARE_TUNNEL_TOKEN`. Don't run the command.
- [ ] Add two **public hostnames** (newer dashboards call them *published application
      routes*):

  | Subdomain | Domain | Service type | URL |
  |---|---|---|---|
  | `n8n` | `ashesborn.com` | HTTP | `n8n:5678` |
  | `evolution` | `ashesborn.com` | HTTP | `evolution:8080` |

  The service URLs are container names on the internal Docker network, not public
  addresses. Cloudflare creates the DNS records automatically.

## 4. Create the Linode

- [ ] Akamai Cloud Manager → **Create Linode**:
  - **Image:** Ubuntu 24.04 LTS
  - **Region:** closest to your users (e.g. Miami, Dallas or Atlanta for Central America)
  - **Plan:** Shared CPU → **Linode 8 GB** ([ADR 0002](decisions/0002-host-on-akamai-linode.md))
  - **Label:** `ashesborn-prod`
  - **Root password:** a long random one, stored in your password manager
  - **SSH Keys:** add your public key (`~/.ssh/id_ed25519.pub`)
  - **Backups add-on:** optional. R2 is the primary backup; this is an extra safety net.

## 5. Firewall: SSH only

- [ ] **Firewalls** → **Create Firewall** → name `ashesborn-prod`:
  - Inbound default policy: **Drop**
  - Inbound rule: **Accept** TCP **22** (SSH). Restrict to your IP if it is fixed.
  - Outbound default policy: **Accept**
- [ ] Assign it to the `ashesborn-prod` Linode.

No ports 80/443 are needed: the tunnel only makes outbound connections
([ADR 0003](decisions/0003-expose-services-via-cloudflare-tunnel.md)).

## 6. Prepare the server

From your computer (replace `SERVER_IP`):

```bash
ssh root@SERVER_IP
```

On the server, as root:

```bash
apt update && apt -y upgrade
apt -y install unattended-upgrades git
timedatectl set-timezone America/Costa_Rica

# Docker Engine + Compose plugin (official install script)
curl -fsSL https://get.docker.com | sh

# Day-to-day user with Docker access; same SSH key as root
adduser --disabled-password --gecos "" deploy
usermod -aG sudo,docker deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
passwd deploy        # sudo password, store it in your password manager

# Only key-based SSH, no root login. A drop-in named 00-* wins over any other
# sshd_config.d file (such as cloud-init's) because sshd uses the first value it reads.
printf 'PasswordAuthentication no\nPermitRootLogin no\n' > /etc/ssh/sshd_config.d/00-ashesborn.conf
sshd -t && systemctl restart ssh
```

Before closing the root session, check that `ssh deploy@SERVER_IP` works from a second
terminal.

## 7. Get the code onto the server

As `deploy`:

```bash
sudo mkdir -p /opt/ashesborn && sudo chown deploy:deploy /opt/ashesborn

# Read-only deploy key for this repo
ssh-keygen -t ed25519 -N "" -f ~/.ssh/github_deploy -C "ashesborn-prod deploy key"
cat ~/.ssh/github_deploy.pub
```

- [ ] GitHub → `CaptainCrunchCR/AshesBornN8NEcosystem` → **Settings → Deploy keys** →
      **Add deploy key**, paste the key, leave **write access off**.

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
    IdentityFile ~/.ssh/github_deploy
EOF
git clone git@github.com:CaptainCrunchCR/AshesBornN8NEcosystem.git /opt/ashesborn
```

## 8. Configure secrets

```bash
cd /opt/ashesborn
cp .env.example .env
chmod 600 .env
openssl rand -hex 32     # run once per secret
nano .env
```

- [ ] Replace **every** `change-me` value. Use `openssl rand -hex 32` output for passwords,
      keys and tokens, and paste in the Cloudflare tunnel token and R2 keys.
- [ ] **Save the finished `.env` in your password manager.** Without `N8N_ENCRYPTION_KEY`,
      a restored backup cannot decrypt the n8n credentials.

## 9. Start the stack

```bash
docker compose up -d
docker compose ps          # all services "Up", postgres "healthy"
docker compose logs -f cloudflared   # look for "Registered tunnel connection"
```

- [ ] Open `https://n8n.ashesborn.com` and create the n8n owner account.
- [ ] Open `https://evolution.ashesborn.com`: it should answer with
      "Welcome to the Evolution API, it is working!".
- [ ] In Cloudflare → Zero Trust → Tunnels, the `ashesborn` tunnel shows **Healthy**.

## 10. Backups

```bash
./scripts/backup.sh
```

- [ ] The run ends with `backup complete`, and the files appear in the R2 bucket.
- [ ] Optional, recommended: create a free check at [healthchecks.io](https://healthchecks.io)
      (daily schedule) and add `BACKUP_HEALTHCHECK_URL=<ping url>` to `.env`. You will get
      an email if a backup fails or doesn't run.
- [ ] Schedule it nightly. Run `sudo touch /var/log/ashesborn-backup.log && sudo chown deploy /var/log/ashesborn-backup.log`,
      then `crontab -e` and add:

```cron
15 3 * * * /opt/ashesborn/scripts/backup.sh >> /var/log/ashesborn-backup.log 2>&1
```

- [ ] **Test a restore** once everything runs, and again every few months:

```bash
./scripts/restore.sh latest
```

## Day-to-day

**Admin UIs** (pgAdmin, RedisInsight) are only reachable through SSH
([ADR 0006](decisions/0006-admin-uis-only-through-ssh-tunnel.md)):

```bash
ssh -L 5050:127.0.0.1:5050 -L 5540:127.0.0.1:5540 deploy@SERVER_IP
```

Then open `http://localhost:5050` (pgAdmin) or `http://localhost:5540` (RedisInsight).

**Updating** an image: change its version in `.env` (keep n8n and runner identical), then:

```bash
./scripts/backup.sh
docker compose pull && docker compose up -d
```

**Pulling repo changes:**

```bash
cd /opt/ashesborn && git pull && docker compose up -d
```

## Restoring onto a brand-new server

If the server is ever lost: repeat steps 4–9 using the **saved `.env`** (the same tunnel
token routes traffic to the new server automatically), then run
`./scripts/restore.sh latest`.
