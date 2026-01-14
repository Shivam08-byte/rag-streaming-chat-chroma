# Release Branching Policy

This document defines how we manage releases using a stable `main` branch and immutable, protected release branches.

## Branches
- **main**: Always the latest stable code. All development merges into `main` via PRs.
- **release branches**: Long-lived, immutable branches cut from `main` at release time. Protected: no force-push, no deletion, PRs required.

## Naming
- Date-based: `release-YYYY-MM-DD` (e.g., `release-2026-01-14`).
- Semantic: `release/vX.Y.Z` (e.g., `release/v1.0.0`). Use when versions are formalized.

## Protection Rules
- Enforce admins.
- Require PRs with ≥1 approval.
- Disallow force pushes.
- Disallow branch deletion.

## Cutting a Release
1. Ensure `main` is green (tests/docs).
2. Create release branch from `main` at the intended commit.
3. Tag a snapshot of the same commit.
4. Create a GitHub Release with notes.

Example commands:
```bash
# Set variables
OWNER=Shivam08-byte
REPO=rag-streaming-chat-chroma
BRANCH=release-2026-01-14
TAG=snapshot-2026-01-14

# Create branch and push
git checkout main
git pull chroma main
git checkout -b "$BRANCH"
git push -u chroma "$BRANCH"

# Tag and release
git tag -a "$TAG" -m "Snapshot $TAG"
git push chroma "$TAG"

gh release create "$TAG" \
  --repo "$OWNER/$REPO" \
  --title "Snapshot $BRANCH" \
  --notes-file docs/reference/RELEASE_NOTES_TEMPLATE.md

# Protect branch (requires repo admin permissions)
printf '{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1,"require_last_push_approval":false},"restrictions":null}' |
  gh api -X PUT \
  "repos/$OWNER/$REPO/branches/$BRANCH/protection" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  --input -
```

## Hotfix Strategy
- Prefer fixing on `main`, then cherry-pick into the latest release branch if needed.
- If urgent, PR directly to the release branch with a cherry-pick from `main` (keep history clean).

## Backporting
- For older supported releases, cherry-pick commits from `main` followed by targeted testing.

## Releases & Tags
- Tags: use `snapshot-YYYY-MM-DD` for date snapshots or `vX.Y.Z` for versions.
- GitHub Releases: publish notes using the template, attach artifacts if applicable.

## Cleanup Policy
- Release branches are not deleted.
- Tags are immutable; never retag existing versions.

## Notes & Changelog
- Keep release notes in GitHub Releases; summarize changes, breaking changes, and upgrade steps.
- Maintain a high-level changelog in `docs/reference/CHANGELOG.md` (optional).

## Automation (Optional)
- Add CI status checks and require them in branch protection.
- Script the release cut via `scripts/release.sh` (future).
