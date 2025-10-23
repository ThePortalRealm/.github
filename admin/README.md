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
````

---

## JSON Files

| File               | Purpose                                 |
| ------------------ | --------------------------------------- |
| `labels.json`      | Canonical label definitions and colors. |
| `issue-types.json` | Canonical org Issue Types.              |
| `repos.json`       | List of active repositories for sync.   |

---

## Token Requirements

Your `gh` token must include:

```
admin:org
repo
workflow
read:org
```

Run `gh auth login` before executing the sync scripts.

---

## Maintenance Notes

* Commit changes to JSONs before running sync.
* Avoid running sync from forks (permissions required).
* Logs print label/issue-type changes for transparency.
