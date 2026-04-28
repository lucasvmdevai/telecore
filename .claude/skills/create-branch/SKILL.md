---
name: create-branch
description: Use when the user wants to start a new branch, "criar branch", "começar feature", "nova task", or before making code changes that should not land on `main` directly. Enforces a `<type>/<issue?>-<slug>` naming convention and starts from an updated `main`.
---

# Create Branch

## Overview

Create a new git branch named with a Conventional-Commit type, an optional issue number, and a kebab-case slug — branched off the latest `origin/main`.

## When to use

- User says "criar branch", "nova branch", "start feature/fix/chore X", or describes work that requires changes.
- Before any non-trivial code change, if currently on `main` or on an unrelated branch.
- **Do not use** for a one-line fix the user asked to commit directly to `main` (rare; ask if unsure).

## Naming convention

```
<type>/<issue?>-<slug>
```

- **type** (required) — one of: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`.
- **issue** (optional but preferred) — bare number, no `#`, e.g. `123`. Enables auto-link in the PR.
- **slug** (required) — lowercase, kebab-case, ≤ 50 chars total branch length, no special chars beyond `-`.

Examples: `feat/123-bearer-auth`, `fix/login-redirect-loop`, `chore/upgrade-credo`.

## Pre-flight checks (abort on failure)

```bash
git status --porcelain   # must be empty — if dirty, ask user to commit/stash
git fetch origin --quiet
```

## Procedure

```bash
git switch main
git pull --rebase --autostash origin main
git switch -c <type>/<issue?>-<slug>
```

If the slug or type wasn't supplied, ask the user — do not invent. Issue number is optional; only include if user mentions it or the work clearly traces to an existing issue.

## Quick reference

| Situation | Action |
|---|---|
| Working tree dirty | STOP — ask user to commit or stash first |
| Already on a feature branch | Ask: continue here, or branch off `main`? |
| `main` is behind origin | `git pull --rebase` updates it before branching |
| User gave Portuguese description | Translate to a short English kebab slug; show the user the proposed name and confirm |
| Branch with same name exists locally | Tell user; offer to switch to it instead |
| Branch with same name exists on remote | STOP — likely someone else's work; ask before overwriting |

## Common mistakes

- **Branching from a stale `main`.** Always `fetch` + `pull --rebase` first.
- **Branching from another feature branch.** Unless explicitly asked (stacked PRs), switch to `main` first.
- **Using underscores or camelCase in slug.** Always kebab-case.
- **Including the `#` in the issue number.** Branch is `feat/123-foo`, not `feat/#123-foo`.
- **Inventing an issue number.** Only include if the user gave one or it's evident.
- **Creating the branch silently.** Always echo the final name back to the user before creating, especially when you derived the slug.
