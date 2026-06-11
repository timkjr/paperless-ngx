#!/usr/bin/env bash
# Sync a paperless-ngx upstream release tag into this fork (dev branch).
#
# Usage:
#   ./sync-upstream.sh              — auto-detect latest upstream tag, merge, push
#   ./sync-upstream.sh v2.20.9     — merge a specific tag
#   ./sync-upstream.sh --check      — show current vs latest, no changes made
#
set -euo pipefail

PUSH=true
CHECK_ONLY=false
TAG=""

for arg in "$@"; do
	case "$arg" in
		--check)     CHECK_ONLY=true ;;
		--no-push)   PUSH=false ;;
		v*)          TAG="$arg" ;;
	esac
done

# ── Resolve tag ──────────────────────────────────────────────────────────────

echo "→ Fetching upstream tag list..."
git fetch upstream --tags --quiet

if [[ -z "$TAG" ]]; then
	TAG=$(git tag --list 'v*' --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
	echo "  Latest upstream tag: $TAG"
fi

CURRENT=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "(none)")
echo "  Current fork tag:    $CURRENT"

if [[ "$TAG" == "$CURRENT" ]]; then
	echo "✓ Already up to date with $TAG — nothing to do."
	exit 0
fi

if $CHECK_ONLY; then
	echo "  → Run without --check to merge $TAG."
	exit 0
fi

# ── Merge ─────────────────────────────────────────────────────────────────────

echo "→ Merging $TAG into $(git branch --show-current)..."
if git merge "$TAG" --no-edit; then
	echo "  Merge completed cleanly."
else
	# Auto-resolve uv.lock by taking upstream's version (standard for this fork)
	if git diff --name-only --diff-filter=U | grep -q "^uv\.lock$"; then
		echo "  Conflict in uv.lock — taking upstream version..."
		git checkout --theirs uv.lock
		git add uv.lock
	fi

	# Check for any remaining conflicts
	REMAINING=$(git diff --name-only --diff-filter=U)
	if [[ -n "$REMAINING" ]]; then
		echo ""
		echo "✗ Unresolved conflicts in:"
		while IFS= read -r f; do echo "    $f"; done <<< "$REMAINING"
		echo ""
		echo "  Resolve manually, then: git add <files> && git merge --continue"
		echo "  Or abort with:          git merge --abort"
		exit 1
	fi

	git merge --continue --no-edit
	echo "  Merge completed (uv.lock auto-resolved)."
fi

# ── Push ──────────────────────────────────────────────────────────────────────

if $PUSH; then
	echo "→ Pushing to origin dev..."
	git push origin dev
	echo "✓ Done — CI will build and Komodo will redeploy."
else
	echo "  --no-push set, skipping push."
	echo "  Run: git push origin dev"
fi
