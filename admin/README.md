# The Portal Realm — Admin Tools

This folder contains the automation scripts and configuration JSONs that unify issue labels, types, and templates across all organization repositories.

---

## Scripts

| Script | Description |
|--------|-------------|
| `sync-labels.sh` | Syncs standardized labels across all repos listed in `repos.json`. |
| `sync-issue-types.sh` | Syncs organization-wide Issue Types via the GitHub GraphQL API. |

Both require `gh` (GitHub CLI) and a token with `admin:org` + `repo` scopes.

```bash
bash .github/admin/sync-labels.sh
bash .github/admin/sync-issue-types.sh
