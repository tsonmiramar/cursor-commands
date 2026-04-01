# Create Commits

## Overview

Optionally use a task list (e.g. from `.apm/APP-1596_Task_Descriptions_and_Acceptance_Criteria.md`) to turn uncommitted changes into task-based branches with conventional, incremental commits. On each repository that has uncommitted changes, identify the most relevant tasks, create one branch per task (named by ticket, e.g. `APP-1617`), move only the changes that belong to that task onto the branch, and commit them using conventional commit format with the ticket id.

## When to use

- You have uncommitted changes across one or more repos and want them split by Jira task.
- A task list file is provided (or exists at a path like `.apm/APP-XXXX_Task_Descriptions_and_Acceptance_Criteria.md`) with sections in the form `## APP-XXXX – Title`.

## Input (optional)

- **Task list file**: Path to a markdown file whose structure matches the reference (sections `## APP-XXXX – Short title`, with **Description** and **Acceptance Criteria**). If not given, prompt for repo (when needed) and create conventional commits on the current branch using branch or ticket name.
- **Repo** (when task list is not given): If multiple repos have uncommitted changes, or the target repo is ambiguous, **prompt the user to specify which repo** to work in (e.g. `ai-cm-server`, `ai-cm-data-access-layer`). If only one repo has changes, use it without prompting unless the user has specified a different repo.

## Steps

### 1. Find repos with uncommitted changes

- From the workspace root, determine which directories are git repositories (e.g. `ai-cm-server`, `ai-cm-data-access-layer`, `ai-case-manager`, etc.).
- In each repo, run `git status` (or equivalent) and note repos that have uncommitted changes (modified, added, or deleted files).
- If no task list is provided, **prompt the user to specify the repo** when the target is ambiguous (e.g. multiple repos with changes, or workspace root is not the repo they want). If exactly one repo has uncommitted changes, use that repo. Then go to **Step 3** to present the breakdown plan (repo + proposed commits) and confirm before **Step 5**.

### 2. Parse the task list and map changes to tasks

- Read the task list file. Extract each task: ticket id `APP-XXXX` and short title/description from the `## APP-XXXX – Title` heading.
- For each repo with uncommitted changes:
  - Get the list of changed files and, if useful, the diff (e.g. `git status`, `git diff`, `git diff --staged`).
  - For each task, decide whether the current changes are “relevant” (e.g. file paths, function names, or diff content align with the task description and acceptance criteria). Prefer clear matches (e.g. E.164/normalization code → APP-1617, inbound webhook route → APP-1620).
  - Produce an ordered list of tasks that have at least one relevant change. If a change could match multiple tasks, assign it to the single best-matching task. Aim to assign every changed file to exactly one task (no orphan changes if possible).

### 3. Present breakdown plan and confirm with user

- **Before creating any branch or commit**, present a clear breakdown plan to the user. Do **not** run `git checkout -b`, `git add`, or `git commit` until the user confirms.
- **With task list**: For each repo and each task, show: branch name (`APP-XXXX`), list of files (and optionally hunks) assigned to that task, and the proposed conventional commit message(s) (incremental breakdown). Include the base branch (e.g. current branch name).
- **Without task list**: Show the target repo, current branch, and the proposed conventional commit message(s) (incremental breakdown) for the uncommitted changes.
- Ask the user to confirm or request changes (e.g. reassign a file, reorder tasks, edit commit messages). Only after explicit confirmation, proceed to Step 4 (no task list) or Step 5 (task list).

### 4. For each repo with uncommitted changes: one branch per task

- Record the current branch (e.g. `feature/APP-1596-sms-opt-out-plans`). All new branches are created from this branch (or from `main` if you prefer and the user agrees).
- For **each** task in the list produced in Step 2 (in an order that respects dependencies if any, e.g. DB before API before frontend), **after the user has confirmed the plan in Step 3**:
  1. **Create branch**: `git checkout -b APP-XXXX` (branch name = ticket id).
  2. **Move relevant changes to this branch**:
     - Stage only the files (and optionally chosen hunks) that belong to this task. Use `git add <path>` for whole files or `git add -p` for partial staging.
     - Do not stage changes that belong to other tasks.
  3. **Commit with conventional, incremental commits**:
     - Use format: `^(feat|fix|build|chore|ci|docs|style|refactor|perf|test|revert)\(APP-XXXX\): short description$` (e.g. `feat(APP-1617): add E.164 phone normalization utility`).
     - Prefer multiple small commits when the change set for this task has distinct logical steps (e.g. “add utility”, “wire normalizer into SMS paths”, “add tests”).
  4. **Push the branch**: Push the task branch to the remote (`git push -u origin APP-XXXX` or equivalent). Use force push (`git push --force-with-lease origin APP-XXXX`) if the branch already exists on the remote and history was rewritten or rebased.
  5. **Return to original branch**: `git checkout <original-branch>` so remaining uncommitted changes are still there for the next task.
  6. Repeat from step 1 for the next task until every relevant change has been committed on some task branch.

- After all tasks are processed, the original branch should have no uncommitted changes that were assigned to a task (all such changes now live on the corresponding `APP-XXXX` branches).

### 5. When there is no task list (or no matching tasks)

- Work in the repo chosen in Step 1 (user-specified or the single repo with changes). Stay on the current branch.
- Stage all uncommitted changes (or a coherent subset).
- Create **conventional and incremental** commits using the **branch name or Jira ticket name**:
  - If the current branch name contains a ticket id (e.g. `feature/APP-1596-sms-opt-out`), use it in the commit: `type(APP-XXXX): short description`.
  - Otherwise use the branch name as scope where appropriate, or a generic scope; keep the conventional format `type(scope): description`.
  - Prefer multiple small commits when changes have distinct logical steps (e.g. add util, add tests, wire into route).
- **Push the commits**: Push the current branch to the remote. Use force push (`git push --force-with-lease`) if the branch already exists on the remote and history was rewritten or rebased.

## Conventions

- **Branch name**: Use the Jira ticket id only, e.g. `APP-1617`, `APP-1620`.
- **Commit message**: Must include the ticket in parentheses and a short, imperative description. Examples:
  - `feat(APP-1617): add E.164 normalization utility`
  - `fix(APP-1620): validate Twilio signature on inbound webhook`
  - `test(APP-1618): add opt-out get/update and last-outbound lookup tests`
- **No co-author or tool tags**: Do not add `Co-authored-by:`, `Made with Cursor`, or similar to commit messages (per project rules).

## Checklist

- [ ] Repos with uncommitted changes identified.
- [ ] When no task list: user prompted for repo if ambiguous; target repo confirmed.
- [ ] Task list parsed and changes mapped to tasks (when task list is provided).
- [ ] **Breakdown plan presented to user (repos, tasks → files, proposed commits); user confirmation obtained before any branch or commit.**
- [ ] For each task with relevant changes: branch `APP-XXXX` created, only relevant changes staged, conventional incremental commits created, branch pushed (force push if necessary), and original branch restored before the next task.
- [ ] When no task list: conventional and incremental commits created using branch name or Jira ticket name, then branch pushed (force push if necessary).
- [ ] All commit messages follow conventional format with ticket id (or scope); no co-author or tool attribution.
