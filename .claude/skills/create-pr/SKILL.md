---
name: create-pr
description: Use when the user wants to open a pull request, "abrir PR", "subir PR", "ship this", or after finishing a feature/fix branch and asking to push it for review. Wraps `gh pr create` with conventional-commit titling, repo PR template, and pre-flight safety checks.
---

# Create Pull Request

## Overview

Open a GitHub PR from the current branch using `gh pr create`, populated from the repo's PR template and a title derived from the branch's commits. Default to **draft** so reviewers aren't paged before CI is green.

## When to use

- User asks to "open a PR", "create PR", "ship this", "subir PR", "abrir PR".
- After committing work on a feature/fix branch and the next logical step is review.
- **Do not use** if `git status` is dirty, branch is `main`/`master`, or there are no commits ahead of `origin/main`.

## Pre-flight checks (run, abort on failure)

```bash
git rev-parse --abbrev-ref HEAD          # must NOT be main / master
git status --porcelain                   # must be empty
git fetch origin --quiet
git rev-list --count origin/main..HEAD   # must be > 0
git rev-list --count HEAD..origin/main   # if > 0, branch is behind — tell user, suggest rebase, STOP
```

If branch has no upstream, push with `git push -u origin HEAD` before creating the PR.

## Title

Use Conventional Commits. Infer from the branch's commits:
- **1 commit ahead of `origin/main`** → use that commit's subject verbatim.
- **>1 commit** → derive `<type>(<scope>): <summary>` from the dominant type/scope (`git log --pretty=%s origin/main..HEAD`). When unclear, ask the user instead of guessing.

Keep titles ≤ 70 chars.

## Body

Read [.github/pull_request_template.md](.github/pull_request_template.md) and fill it in:
- **Summary** — one paragraph: what changed and why (from commits + diff).
- **Changes** — bullet list grouped by area; one bullet per logical change, not per file.
- **Test plan** — leave checkboxes unchecked unless you actually ran the command in this session and saw it pass.
- **Related issues** — auto-detect issue number from branch name pattern `<type>/<num>-<slug>` (e.g. `feat/123-bearer-auth` → `Closes #123`). Omit the section if no number found.
- Delete unused/empty optional sections (don't leave bare headers with empty content).

Pass via heredoc to preserve formatting:

```bash
gh pr create --draft \
  --title "feat(api): add bearer-token auth" \
  --body "$(cat <<'EOF'
## Summary
...

## Changes
- ...

## Test plan
- [ ] `mix test` passes

Closes #123
EOF
)"
```

## After creation

Print the PR URL returned by `gh`. Tell the user it was opened as **draft** and that they should mark ready for review when CI passes.

## Quick reference

| Situation | Action |
|---|---|
| Branch behind `origin/main` | STOP — tell user to rebase first |
| Working tree dirty | STOP — ask user to commit/stash |
| On `main` branch | STOP — refuse, suggest `create-branch` first |
| No upstream set | `git push -u origin HEAD` then create PR |
| User says "ready, not draft" | Drop `--draft` flag |
| Repo has no PR template | Use the default Summary / Changes / Test plan structure inline |

## Common mistakes

- **Checking Test plan boxes you didn't run.** Only mark `[x]` for commands you actually executed and saw pass in this session.
- **Wall-of-text Summary.** One paragraph. Move detail into Changes bullets.
- **Title rephrasing the branch name.** Title is for reviewers — describe the change, not the branch.
- **Force-pushing to fix the PR after creation.** If the PR is wrong, edit it (`gh pr edit`), don't recreate.
- **Opening from `main`.** Always work from a feature branch; if user is on `main`, refuse and point to `create-branch`.
- **Including AI co-author trailers** unless the user has it configured project-wide.
