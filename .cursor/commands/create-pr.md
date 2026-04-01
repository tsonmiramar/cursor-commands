# Create PR

## Overview

Create a well-structured merge request (MR) using the **glab** CLI, with a proper description, labels, and reviewers. The MR title must use **conventional commit style** with a `feat` or `fix` prefix and the ticket number (e.g. `feat(APP-1618): add contact point model` or `fix(APP-1620): inbound webhook validation`). The ticket in the title must match the branch name (e.g. branch `APP-1620` → title includes `APP-1620`).

## Steps (using glab)

1. **Prepare branch**
   - Ensure all changes are committed: `git status`
   - Push branch to remote: `git push -u origin <branch>`
   - Rebase on main if needed: `git fetch origin main && git rebase origin/main`
2. **Lint and fix (before creating the PR)**
   - Run the **Lint and Fix** command (`.cursor/commands/lint-fix.md`) for the relevant repo. Do not create the MR until lint and tslint pass and any fixes are committed.
3. **Generate PR description**
   - Run the **Generate PR Description** command (`.cursor/commands/generate-pr-description.md`) to produce the MR description from this branch’s changes.
   - Use the output as the description body, or save it to a file (e.g. `description.md`) for use with `-F`.
4. **Confirm title and description**
   - Present the proposed MR **title** and **description** to the user.
   - Ask the user to confirm or request edits before proceeding.
   - Do not create or push the MR until the user confirms.
5. **Create MR with glab**
   - Title and description: Use the title and description from **Generate PR Description** (see that command for the title rule).
   - Create MR using the generated description: `glab mr create -t "feat(APP-XXXX): Short description" -d "Description body"` or `glab mr create -t "feat(APP-XXXX): Title" -F description.md`
6. **After creation (optional)**
   - Add labels: `glab mr update <id> --label "label1,label2"`
   - Assign reviewers: `glab mr update <id> --reviewer @user`
   - Link issues: reference in description with `APP-XXXX` or `#issue-id`

## glab MR create options

- `-t, --title` – MR title in conventional form: `feat(APP-XXXX): description` or `fix(APP-XXXX): description`; ticket must match branch.
- `-d, --description` – Description text (use output from **Generate PR Description** command).
- `-F, --description-file` – Read description from file (e.g. file produced by **Generate PR Description**).
- `--target-branch` – Target branch (default: main).
- `--fill` – Use commit details for title/description.

## PR description content

The **Generate PR Description** command produces a description that includes: summary, changes made, testing, related issues, and additional notes. Use that output (or its checklist) as the MR description body.
