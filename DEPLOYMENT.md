# Paperless-NGX Custom Fork - Deployment Guide

## Overview

Custom fork of Paperless-NGX with:

- **Frontend**: Lazy-loading for filter dropdowns (dashboard 27s → <2s)
- **Backend**: Upstream v2.20.7 subquery optimization (tags API 30s timeout → ~2.7s)
- **Security**: v2.20.7 IDOR fix (GHSA-x395-6h48-wr8v)

## Automated CI/CD Pipeline

**The pipeline is fully automated. Normal workflow is just `git push`.**

```
git push origin dev
  → Forgejo Actions picks up job (runner: development-docker)
  → Docker build on development LXC (~1 min cached, ~9 min cold)
  → Image pushed to git-forgejo.k-lab.lan:3000/timkjr/paperless-custom
  → Komodo detects new digest on :custom-fix tag
  → Auto-redeploys paperless-ngx stack
```

### Image Tags Produced

| Tag                  | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `:custom-fix`        | Stable tag — Komodo deployment target             |
| `:dev`               | Always-latest                                     |
| `:dev-YYYYMMDD-SHA8` | Rollback reference (e.g. `dev-20260217-f0fa9154`) |

## Git Remotes

- **origin**: `git@git.k-lab.lan:timkjr/paperless-custom.git` (Forgejo - primary)
- **fork**: `https://github.com/timkjr/paperless-ngx.git` (GitHub - mirror)
- **upstream**: `https://github.com/paperless-ngx/paperless-ngx.git` (Official repo)

## Production Details

**Host:** paperless-ngx.k-lab.lan
**Image:** `git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:custom-fix`
**Managed by:** Komodo (auto-redeploy on digest change)
**Config repo:** separate Docker config repo (also CI/CD managed)

## CI/CD Infrastructure

### Forgejo Actions Runner

- **Name:** `development-docker`
- **Label:** `docker-builder` (host mode)
- **LXC:** `development.k-lab.lan`
- **Service:** `forgejo-runner-dev.service`
- **Working dir:** `/var/lib/forgejo-runner-dev/`
- **Binary:** `/usr/local/bin/forgejo-runner` v12.5.2

```bash
# Check runner status
sudo systemctl status forgejo-runner-dev

# View runner logs
sudo journalctl -u forgejo-runner-dev -f
```

### Workflow File

`.forgejo/workflows/build.yml` — triggers on push to `dev` branch.

> **Note:** Uses `.forgejo/workflows/` not `.github/workflows/` — Forgejo-specific.

### Required Secret

In Forgejo repo Settings → Secrets → Actions:

| Secret           | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `REGISTRY_TOKEN` | Forgejo PAT with `package:read` + `package:write` scope |

> `github.token` lacks `package:write` in Forgejo — the PAT is required.

### Registry

- **URL:** `git-forgejo.k-lab.lan:3000` (direct — NOT through Caddy)
- **User:** `timkjr`
- **Note:** Large images fail through `git.k-lab.lan` (Caddy proxy). Always use direct URL.

### Komodo Configuration

- Registry Account: `git-forgejo.k-lab.lan:3000` with PAT token
- Stack: watches `:custom-fix` tag, auto-redeploys on digest change

## Merging Upstream Updates

```bash
# Fetch upstream tags
git fetch upstream --tags

# Check what's new
git log --oneline d27a5f688..vX.Y.Z

# Merge on a branch first
git checkout -b upstream-vX.Y.Z
git merge vX.Y.Z

# Resolve conflicts (expect: ci.yml deleted/modified, uv.lock content conflict)
# Our changes are in src-ui/ — upstream changes are in src/documents/
# Very unlikely to conflict

git checkout dev
git merge upstream-vX.Y.Z --ff-only
git push origin dev
```

## Manual Rollback

If a deployment causes issues:

### Via Komodo

Select paperless-ngx stack → Rollback to previous version

### Via Image Tag

```bash
ssh timkjr@paperless-ngx.k-lab.lan
cd ~/docker-configs/paperless-ngx

# Edit docker-compose.yml, change tag from custom-fix to a specific date tag:
# image: git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:dev-20260217-f0fa9154

docker compose pull webserver
docker compose up -d webserver
```

### List Available Tags

```bash
curl -s https://git-forgejo.k-lab.lan:3000/api/v1/packages/timkjr/container/paperless-custom/tags
```

## Troubleshooting CI

| Symptom                          | Cause                              | Fix                                       |
| -------------------------------- | ---------------------------------- | ----------------------------------------- |
| "Waiting for runner"             | Wrong label in workflow            | Check `runs-on: docker-builder`           |
| "x509 certificate" error         | CA cert not trusted                | See CA cert install procedure in memory   |
| `unauthorized: reqPackageAccess` | `github.token` used instead of PAT | Use `secrets.REGISTRY_TOKEN`              |
| Push fails through git.k-lab.lan | Caddy can't handle large images    | Use `git-forgejo.k-lab.lan:3000` directly |
| Build takes 9+ min               | Cold Docker cache                  | Normal on first run, ~1 min after         |
