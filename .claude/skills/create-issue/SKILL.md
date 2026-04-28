---
name: create-issue
description: Use when the user wants to file a GitHub issue, "criar issue", "abrir ticket", report a bug, or capture a feature/chore. Wraps `gh issue create` with the repo's issue templates (bug, feature, chore) and Conventional-Commit style titles.
---

# Create Issue

## Overview

File a GitHub issue using the repo's templates in `.github/ISSUE_TEMPLATE/`. Pick the right template for the work type, fill it from what the user described, and use a Conventional-Commit-style title.

## When to use

- User asks to "criar issue", "abrir issue/ticket", "log a bug", "track this", or describes work that should be queued instead of done now.
- After triaging a bug report or feature idea you want to persist.
- **Do not use** if the user is asking you to *do* the work right now and an issue would just be busywork.

## Choose the template

| User intent | Template | Title prefix |
|---|---|---|
| Something is broken / unexpected behavior | `bug_report.md` | `bug: ` |
| New capability or behavior change | `feature_request.md` | `feat: ` |
| Refactor, dep upgrade, tooling, tech debt | `chore.md` | `chore: ` |

If the repo has no `.github/ISSUE_TEMPLATE/`, fall back to a minimal `## Context` / `## Acceptance criteria` body and a Conventional-Commit title.

## Title

- Conventional Commit prefix per the table above.
- Imperative mood, ≤ 70 chars, no trailing period.
- Examples: `bug: login redirects in a loop after 401`, `feat: support SSO via Google Workspace`, `chore: upgrade credo to 1.7`.

## Body

Read the chosen template file from the repo and fill every section that applies. Rules:
- **Don't ask the user every field one by one** — fill what you can infer from the conversation, leave concrete `<!-- placeholders -->` only where information is genuinely missing, and surface those gaps in your reply.
- **Acceptance criteria** must be specific and testable, not aspirational ("Login works" → bad; "POST /sessions returns 200 with a valid token for valid credentials" → good).
- **Steps to reproduce** for bugs: numbered list, exact commands or clicks, expected vs actual.
- Delete any optional section that is empty rather than leaving the bare header.

## Procedure

```bash
gh issue create \
  --title "<prefixed title>" \
  --label "<label-from-template-or-omit>" \
  --body "$(cat <<'EOF'
<filled template content>
EOF
)"
```

If the user mentioned an assignee, add `--assignee <login>`. Don't add reviewers/projects unless explicitly asked.

## After creation

Print the issue URL returned by `gh`. If the user is likely to start the work next, suggest the matching branch name (e.g. `feat/<num>-<slug>`) for the `create-branch` skill.

## Quick reference

| Situation | Action |
|---|---|
| User describes 3 unrelated things | Ask if they want 3 issues; do not bundle |
| User gave only a vague title | Ask 1-2 clarifying questions before creating |
| Repo has no templates | Use minimal Context / Acceptance criteria body |
| Bug with no repro | Ask for repro before filing — vague bug reports rot |
| Issue is a duplicate | Search first with `gh issue list --search "<keywords>"` and link rather than re-file |

## Common mistakes

- **Creating an issue and immediately starting the work** without asking — defeats the purpose of triage.
- **Walls of `<!-- TODO -->` placeholders** in the body. Either fill it or trim the section.
- **Vague acceptance criteria.** "Should work well" is not a criterion.
- **Skipping the label.** Templates set labels via frontmatter, but pass `--label` as a safety net if `gh` doesn't pick them up.
- **Using `#123` in the title.** GitHub will not auto-link issue numbers in titles; reference them in the body if relevant.
