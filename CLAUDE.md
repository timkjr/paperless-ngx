# CLAUDE.md — paperless-custom

Custom fork of [paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) with homelab performance fixes, deployed to `paperless-ngx.k-lab.lan`.

> **Persistent context:** `~/.claude/projects/-home-timkjr-dev-paperless-custom/memory/MEMORY.md` — CI/CD details, performance fix history, infrastructure notes.

---

## What This Fork Changes

Our changes are **frontend only** (`src-ui/`). Backend (`src/documents/`, `src/paperless_mail/`) is untouched upstream code.

| Fix                        | File                                                                               | Impact              |
| -------------------------- | ---------------------------------------------------------------------------------- | ------------------- |
| Lazy-load filter dropdowns | `src-ui/src/app/components/document-list/filter-editor/filter-editor.component.ts` | Dashboard 27s → <2s |

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

| File                                                                               | Resolution                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `uv.lock`                                                                          | Take theirs — `git checkout --theirs uv.lock && git add uv.lock`                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `.forgejo/workflows/ci.yml`                                                        | Keep our deletion (we don't run upstream CI)                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `src-ui/src/main.ts`                                                               | Keep our functional interceptor imports (`withCsrfInterceptor`, `withApiVersionInterceptor`). Add any new upstream class-based interceptors via `HTTP_INTERCEPTORS` token — `withInterceptorsFromDi()` in `provideHttpClient()` handles them. Don't take upstream's class rewrites of our functional interceptors. In v3+: `APP_INITIALIZER` → `provideAppInitializer`, `withFetch` added to `provideHttpClient`, `HTTP_INTERCEPTORS` usage reduced in favour of `withInterceptors`. |
| `src-ui/src/app/components/document-list/filter-editor/filter-editor.component.ts` | **v3+:** Keep our lazy-load changes (dropdown open handlers). Integrate upstream's tantivy search changes: `FILTER_SIMPLE_TEXT`/`FILTER_SIMPLE_TITLE` new types, `SelectionData`/`SelectionDataItem` import moved from `document.service` to `results` module, `TourNgBootstrapModule` → `TourNgBootstrap`. Our changes and theirs are in different areas of the file.                                                                                                               |

Our changes (`src-ui/`) and upstream changes (`src/documents/`, `src/paperless_mail/`) rarely overlap.

**v3 note:** Upstream added virtual scrolling to `filterable-dropdown.component.ts` (commit `6442fdc23`) — complementary to our lazy-load fix, not a replacement. Their fix improves render speed; ours prevents the initial API fetch. Keep both.

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

| Branch | Purpose                                                 |
| ------ | ------------------------------------------------------- |
| `dev`  | Active development, triggers CI on push                 |
| `main` | Unused — upstream main is tracked via `upstream` remote |

### Remotes

| Remote     | URL                                                  | Purpose              |
| ---------- | ---------------------------------------------------- | -------------------- |
| `origin`   | `git@git.k-lab.lan:timkjr/paperless-custom.git`      | Primary (Forgejo)    |
| `upstream` | `https://github.com/paperless-ngx/paperless-ngx.git` | Upstream releases    |
| `fork`     | `https://github.com/timkjr/paperless-ngx.git`        | GitHub fork (unused) |

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

| Task                   | Tool                                           |
| ---------------------- | ---------------------------------------------- |
| Multi-step reasoning   | `mcp__sequential-thinking__sequentialthinking` |
| External docs/research | `Agent(subagent_type="gemini")`                |
| Store discoveries      | `mcp__memory-service__store_memory`            |

---

## Troubleshooting

| Issue                                           | Fix                                                                                  |
| ----------------------------------------------- | ------------------------------------------------------------------------------------ |
| CI build fails auth                             | Check `REGISTRY_TOKEN` secret in Forgejo repo settings                               |
| Merge conflict beyond `uv.lock`                 | Inspect diff — our changes are `src-ui/` only, so conflicts elsewhere are unexpected |
| `git status` shows diverged from `upstream/dev` | Fix tracking: `git branch --set-upstream-to=origin/dev dev`                          |
| Komodo not redeploying                          | Check `:custom-fix` tag was pushed; verify Komodo stack config                       |
| Build slow (9+ min)                             | Normal for cold build; cached builds ~1 min                                          |

<!-- gortex:communities:start -->

## Codebase Overview (generated by Gortex)

- **Languages:** json (primary), , bash, contract, css, dockerfile, dotenv, editorconfig, gitignore, go, html, image, javascript, js, markdown, mcp_config, pdf, po, py, python, scss, spring, text, toml, ts, typescript, yaml
- **Most-referenced symbols:** `Document` (803 usages), `documents.models.Document` (756 usages), `django.db.models` (602 usages), `django.utils.translation.gettext_lazy` (544 usages), `Path` (513 usages), `add` (386 usages), `django.test.override_settings` (305 usages), `patch` (299 usages), `django.contrib.auth.models.User` (283 usages), `rest_framework.serializers` (273 usages)
- **Graph size:** 39305 nodes, 131701 edges
- **Breakdown:** 111 builtins, 6 config_keys, 226 contracts, 2107 docs, 4131 files, 2016 functions, 2 generic_params, 89 images, 5589 imports, 67 interfaces, 523 locals, 3470 methods, 1502 modules, 3295 params, 1 resources, 1 strings, 3 teams, 37 todos, 1066 types, 15063 variables

## MANDATORY: Use Gortex MCP tools instead of Read/Grep/Glob

Gortex is running as an MCP server. You **MUST** prefer graph queries over file reads on every task in this repo — `search_symbols`, `find_usages`, `get_symbol_source`, `get_editing_context`, `smart_context`, `edit_symbol` / `edit_file` / `rename_symbol` / `batch_edit`. Hook posture is configurable; follow every Gortex hook instruction even when `Read` / `Grep` / `Glob` remain callable. The full per-tool catalog loads via `tools/list` — not restated here.

### Calibration: the graph narrows scope, source confirms behavior

The mandate above stands — but graph queries _narrow scope_, they do not _replace reading the implementation_. The graph tells you **where** the logic lives and **what** connects to it; the source tells you **how** it behaves. For the symbol you are about to change or depend on, read its full body with `get_symbol_source` — do not act on a one-line summary alone.

Be especially deliberate with **behavior-critical code** — database migrations, retry / fallback / error-recovery paths, compatibility shims, concurrency-sensitive sections, and the tests that pin them. For these, call `get_symbol_source` and read the real implementation; never pass `compress_bodies:true`, which elides exactly the branches that carry the risk. Reserve compressed bodies and graph summaries for breadth (surveying many symbols); use full source for the few you are about to commit to.

## Required workflow (every task on this repo)

These are not suggestions — run each step at the trigger.

1. Confirm the daemon is up with `index_health` (cheap liveness + scope). Call `graph_stats` only when you actually need node/edge counts or `per_repo` orientation — it returns a large payload and can block during warmup.
2. If `total_nodes` is 0, **call** `index_repository` with `"."` before anything else.
3. In multi-repo mode, **call** `get_active_project` to check scope; use `set_active_project` to switch.
4. Open a non-trivial task with `smart_context` for orientation. For a single known symbol or file, go straight to `search_symbols` / `get_symbol_source` — don't front-load `smart_context` before every read.
5. Before editing a file, **call** `get_editing_context` on it first.
6. Before changing any function signature, **call** `verify_change` to catch broken callers and interface implementers (cross-repo).
7. For any refactor, **call** `get_edit_plan` then `batch_edit` to apply atomically.
8. Verify with the project's real build/test. Reserve `check_guards` for guard-relevant changes and `get_test_targets` to find the tests covering a substantive change — not mechanically after every edit.

<!-- gortex:skills:start -->

## Community Skills

| Area                                    | Description | Skill                                             |
| --------------------------------------- | ----------- | ------------------------------------------------- |
| App Data 64 Dirs                        | 952 symbols | `/gortex-app-data-64-dirs`                        |
| 13 Dirs                                 | 532 symbols | `/gortex-13-dirs`                                 |
| Documents Tests 6 Dirs                  | 297 symbols | `/gortex-documents-tests-6-dirs`                  |
| 7 Dirs Paperless Mail Models Mailaccou  | 269 symbols | `/gortex-7-dirs-paperless-mail-models-mailaccou`  |
| 6 Dirs Add                              | 257 symbols | `/gortex-6-dirs-add`                              |
| App Services 16 Dirs                    | 231 symbols | `/gortex-app-services-16-dirs`                    |
| App Data 7 Dirs                         | 230 symbols | `/gortex-app-data-7-dirs`                         |
| 3 Dirs Rest Framework Serializers       | 201 symbols | `/gortex-3-dirs-rest-framework-serializers`       |
| 7 Dirs Django Contrib Auth Models User  | 200 symbols | `/gortex-7-dirs-django-contrib-auth-models-user`  |
| 3 Dirs Rest Framework Response Response | 190 symbols | `/gortex-3-dirs-rest-framework-response-response` |
| App Services 22 Dirs                    | 187 symbols | `/gortex-app-services-22-dirs`                    |
| 5 Dirs Get                              | 184 symbols | `/gortex-5-dirs-get`                              |
| App Data 2 Dirs                         | 169 symbols | `/gortex-app-data-2-dirs`                         |
| 8 Dirs Lower                            | 162 symbols | `/gortex-8-dirs-lower`                            |
| Documents Tests 1 Dirs Dumps            | 162 symbols | `/gortex-documents-tests-1-dirs-dumps`            |
| 4 Dirs Magicmock                        | 162 symbols | `/gortex-4-dirs-magicmock`                        |
| Documents Tests 8 Dirs                  | 155 symbols | `/gortex-documents-tests-8-dirs`                  |
| App Documentdetailcomponent             | 149 symbols | `/gortex-app-documentdetailcomponent`             |
| 4 Dirs Customfield                      | 144 symbols | `/gortex-4-dirs-customfield`                      |
| Documents 7 Dirs                        | 132 symbols | `/gortex-documents-7-dirs`                        |

<!-- gortex:skills:end -->

<!-- gortex:communities:end -->
