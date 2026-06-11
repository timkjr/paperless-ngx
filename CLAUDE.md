# CLAUDE.md — paperless-custom

Custom fork of [paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) with homelab performance fixes, deployed to `paperless-ngx.k-lab.lan`.

> **Persistent context:** `~/.claude/projects/-home-timkjr-dev-paperless-custom/memory/MEMORY.md` — CI/CD details, performance fix history, infrastructure notes.

---

## What This Fork Changes

Our changes are **frontend only** (`src-ui/`). Backend (`src/documents/`, `src/paperless_mail/`) is untouched upstream code.

| Fix | File | Impact |
|-----|------|--------|
| Lazy-load filter dropdowns | `src-ui/src/app/components/common/filter-editor/filter-editor.component.ts` | Dashboard 27s → <2s |

Everything else — backend, Dockerfile, CI workflow — is either upstream or homelab-specific infrastructure.

---

## Merging Upstream Releases

Use the included script. It fetches the tag, merges, auto-resolves `uv.lock`, and pushes to trigger CI:

```bash
./sync-upstream.sh              # auto-detect latest upstream tag
./sync-upstream.sh v2.20.9     # specific tag
./sync-upstream.sh --check     # check current vs latest, no changes
./sync-upstream.sh --no-push   # merge locally without pushing
```

**Known conflict patterns:**

| File | Resolution |
|------|-----------|
| `uv.lock` | Take theirs — `git checkout --theirs uv.lock && git add uv.lock` |
| `.forgejo/workflows/ci.yml` | Keep our deletion (we don't run upstream CI) |
| `src-ui/src/main.ts` | Keep our functional interceptor imports (`withCsrfInterceptor`, `withApiVersionInterceptor`). Add any new upstream class-based interceptors via `HTTP_INTERCEPTORS` token — `withInterceptorsFromDi()` in `provideHttpClient()` handles them. Don't take upstream's class rewrites of our functional interceptors. |

Our changes (`src-ui/`) and upstream changes (`src/documents/`, `src/paperless_mail/`) rarely overlap.

---

## CI/CD Pipeline

`git push origin dev` → Forgejo Actions → Docker build → registry → Komodo redeploys

```
Branch: dev
Runner: docker-builder (on development.k-lab.lan)
Image:  git-forgejo.k-lab.lan:3000/timkjr/paperless-custom
Tags:   :custom-fix  :dev  :dev-YYYYMMDD-<sha>
Production tag: :custom-fix (what Komodo pulls)
```

**Registry:** Push directly to `git-forgejo.k-lab.lan:3000` — large images fail through Caddy.

**Secret:** `REGISTRY_TOKEN` (PAT with `package:write`). `github.token` does not work with Forgejo registry.

**Build time:** ~1 min (cached layers), ~9 min (cold/base image change).

---

## Development

### Branches

| Branch | Purpose |
|--------|---------|
| `dev` | Active development, triggers CI on push |
| `main` | Unused — upstream main is tracked via `upstream` remote |

### Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@git.k-lab.lan:timkjr/paperless-custom.git` | Primary (Forgejo) |
| `upstream` | `https://github.com/paperless-ngx/paperless-ngx.git` | Upstream releases |
| `fork` | `https://github.com/timkjr/paperless-ngx.git` | GitHub fork (unused) |

### Pre-commit Hooks

Upstream pre-commit is configured. Hooks that commonly fire on our scripts:

- **beautysh** — reformats shell scripts automatically (re-stage after it runs)
- **shellcheck** — enforces shell style; avoid `sed` in scripts (use `while read` instead)
- **codespell** — spell-checks everything

### Frontend Development

The Angular frontend lives in `src-ui/`. Upstream uses `ng` + `jest`.

```bash
cd src-ui
npm install       # install deps
npm start         # dev server (proxies to running backend)
npm test          # run jest unit tests
```

Our lazy-load fix is in `filter-editor.component.ts` — preserve it on every upstream merge.

---

## Tool Selection

ChunkHound is indexed and configured for this project (`.chunkhound/db`). Use it for code search.

| Task | Tool |
|------|------|
| Search codebase (functions, patterns) | `mcp__chunkhound__code_research` |
| Multi-step reasoning | `mcp__sequential-thinking__sequentialthinking` |
| External docs/research | `Agent(subagent_type="gemini")` |
| Store discoveries | `mcp__memory-service__store_memory` |

Do not use `Grep` or `Bash` for code search — ChunkHound is indexed and faster.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CI build fails auth | Check `REGISTRY_TOKEN` secret in Forgejo repo settings |
| Merge conflict beyond `uv.lock` | Inspect diff — our changes are `src-ui/` only, so conflicts elsewhere are unexpected |
| `git status` shows diverged from `upstream/dev` | Fix tracking: `git branch --set-upstream-to=origin/dev dev` |
| Komodo not redeploying | Check `:custom-fix` tag was pushed; verify Komodo stack config |
| Build slow (9+ min) | Normal for cold build; cached builds ~1 min |
