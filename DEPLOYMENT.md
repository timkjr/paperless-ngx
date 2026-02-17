# Paperless-NGX Custom Fork - Deployment Guide

## Overview

This is a custom fork of Paperless-NGX with frontend performance optimizations for handling 4,000+ tags. The production deployment uses a custom Docker image hosted in Forgejo.

## Git Remotes

- **origin**: `git@git.k-lab.lan:timkjr/paperless-custom.git` (Forgejo - primary)
- **fork**: `https://github.com/timkjr/paperless-ngx.git` (GitHub - mirror)
- **upstream**: `https://github.com/paperless-ngx/paperless-ngx.git` (Official repo)

## Production Deployment

**Host:** paperless-ngx.k-lab.lan (LXC container)
**Image:** `git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:custom-fix`
**Config Location:** `~/docker-configs/paperless-ngx/docker-compose.yml`
**Managed By:** Komodo

## Build & Deploy Process

### Prerequisites

1. Ensure you're on the correct branch:

   ```bash
   git checkout dev
   git pull origin dev
   ```

2. Verify your changes are committed:
   ```bash
   git status
   git log --oneline -5
   ```

### Option 1: Manual Build & Deploy

#### Step 1: Build Docker Image

Build the multi-stage Docker image (compiles frontend, packages backend):

```bash
# From the repo root (/home/timkjr/packages/paperless-ngx)
docker build \
  --tag git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:custom-fix \
  --tag git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:dev-$(date +%Y%m%d) \
  --file Dockerfile \
  .
```

**Build Time:** ~15-20 minutes (frontend compilation is slow)
**Watch for:** Frontend build errors in the `compile-frontend` stage

#### Step 2: Push to Forgejo Registry

```bash
# Push the custom-fix tag (production)
docker push git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:custom-fix

# Optional: Push dated tag for rollback capability
docker push git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:dev-$(date +%Y%m%d)
```

**Note:** Ensure you're authenticated to Forgejo:

```bash
docker login git-forgejo.k-lab.lan:3000
# Use your Forgejo credentials
```

#### Step 3: Deploy to Production

**Option A: Via Komodo (Recommended)**

- Log into Komodo web interface
- Find the paperless-ngx stack
- Click "Redeploy" or "Pull & Restart"

**Option B: Manual SSH Deployment**

```bash
# SSH to production host
ssh timkjr@paperless-ngx.k-lab.lan

# Navigate to config directory
cd ~/docker-configs/paperless-ngx

# Pull latest image
docker compose pull webserver

# Recreate container (zero downtime with health checks)
docker compose up -d webserver

# Verify deployment
docker compose ps
docker compose logs -f webserver | head -50
```

#### Step 4: Verify Deployment

```bash
# Check container status (should be "healthy")
ssh timkjr@paperless-ngx.k-lab.lan "docker ps | grep paperless"

# Check when image was built (should match your build time)
ssh timkjr@paperless-ngx.k-lab.lan "docker inspect paperless-ngx-webserver-1 --format='{{.Created}}'"

# Test the application
curl -I https://paperless-ngx.k-lab.lan
```

### Option 2: Automated CI/CD (TODO)

Currently, there's no CI/CD pipeline. To set this up:

1. Configure Forgejo Actions or GitHub Actions
2. Build on commit to `dev` branch
3. Push to Forgejo registry with branch name as tag
4. Trigger Komodo webhook to redeploy

### Rollback Procedure

If the new deployment has issues:

```bash
# SSH to production
ssh timkjr@paperless-ngx.k-lab.lan
cd ~/docker-configs/paperless-ngx

# Edit docker-compose.yml to use previous tag
nano docker-compose.yml
# Change: image: git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:custom-fix
# To:     image: git-forgejo.k-lab.lan:3000/timkjr/paperless-custom:dev-20260131

# Redeploy
docker compose pull webserver
docker compose up -d webserver
```

**List available tags:**

```bash
# Query Forgejo registry API
curl -s https://git-forgejo.k-lab.lan:3000/api/v1/packages/timkjr/container/paperless-custom/tags
```

## Key Changes in This Fork

### Frontend Performance Optimizations (Jan 2026)

**Problem:** Loading 4,000+ tags caused browser timeouts and UI freezing.

**Solutions Implemented:**

1. **Tag Input Lazy Loading** (`src-ui/src/app/components/common/input/tags/tags.component.ts`)

   - Changed from `listAll()` to `listFiltered()` with pagination
   - Loads only 50 tags per request
   - Implements typeahead with 200ms debounce
   - Separately loads selected tags via `getFew()`

2. **Virtual Scrolling** (`src-ui/src/app/components/common/filterable-dropdown/`)
   - Uses Angular CDK Virtual Scroll Viewport
   - Only renders visible items in DOM
   - Buffer: 400-800px (smooth scrolling without lag)

**Commits:**

- `e9883ccbb` - feat(ui): optimize tag dropdown with virtual scrolling (Jan 31, 2026)
- `ccc74d5b5` - test(ui): improve test coverage for dropdowns and tag input

### Known Issues

- Backend API may still be slow for tag queries (see TROUBLESHOOTING.md)
- Pagination limit of 50 tags might need tuning based on API performance
- Virtual scrolling requires Angular CDK 21.x (verify in package.json)

## Testing Changes Locally

### Run Frontend Development Server

```bash
cd src-ui
pnpm install
pnpm run start
```

Access at http://localhost:4200 (proxies API to production)

### Build Frontend for Production Testing

```bash
cd src-ui
pnpm run build
# Output: src-ui/dist/paperless-ui/browser/
```

### Run Full Stack Locally

```bash
# Use docker-compose from /docker/compose/
docker compose -f docker/compose/docker-compose.postgres-tika.yml up -d
```

## Maintenance

### Sync with Upstream

Periodically merge upstream changes:

```bash
git fetch upstream
git checkout dev
git merge upstream/dev

# Resolve conflicts (especially in src-ui/ frontend code)
# Test thoroughly before deploying
```

### Update Dependencies

**Frontend:**

```bash
cd src-ui
pnpm update
pnpm audit fix
```

**Backend:** (handled by Dockerfile, uses uv package manager)

```bash
# Check for updates in requirements.txt or pyproject.toml
```

## Troubleshooting

### Build Failures

**Frontend compilation errors:**

- Check Node.js version (should match Dockerfile: node:24)
- Clear pnpm cache: `cd src-ui && pnpm store prune`
- Check for TypeScript errors in modified files

**Docker build fails:**

- Increase Docker build memory (Settings → Resources)
- Check disk space: `df -h`
- Review build logs for specific stage failures

### Deployment Issues

**Container won't start:**

```bash
ssh timkjr@paperless-ngx.k-lab.lan "docker compose logs webserver"
```

**Still seeing old code:**

- Hard refresh browser (Ctrl+Shift+R)
- Clear browser cache
- Check if image actually updated:
  ```bash
  docker inspect paperless-ngx-webserver-1 | grep -A5 "Image"
  ```

**Database migration errors:**

```bash
# Run migrations manually
docker compose exec webserver python3 manage.py migrate
```

## Related Documentation

- **Frontend Changes:** See git commit `e9883ccbb` for detailed diff
- **Production Config:** `~/docker-configs/paperless-ngx/GEMINI.md`
- **Performance Tuning:** `~/docker-configs/paperless-ngx/pngx.env`
- **Official Docs:** https://docs.paperless-ngx.com

## Emergency Contacts

- **User:** timkjr
- **Forgejo:** https://git-forgejo.k-lab.lan
- **Production URL:** https://paperless-ngx.k-lab.lan
- **Upstream Issues:** https://github.com/paperless-ngx/paperless-ngx/issues

---

**Last Updated:** 2026-02-06
**Maintained By:** Tim K (timkjr)
