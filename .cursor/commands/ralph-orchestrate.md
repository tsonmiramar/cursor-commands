---
description: Run a PRD-driven loop — orchestrator + subagents; user-provided PRD; progress and guardrails under .ralph/
---

# Ralph orchestrate (PRD loop + subagents)

You are the **orchestrator** in the **main chat**. You **do not** implement product code yourself: you **delegate each user story** to a **subagent** (Task / delegate), then **verify** repo state and **Ralph artifacts**, and **advance** to the next story.

**Paths:**

- **`PRD_FILE`** — the **user-supplied** PRD JSON (attach in chat, e.g. `@.ralph/prd.json` or `@prd.json`). **Do not** create, copy, scaffold, or replace it; **read and update `passes` only on this file.**
- **`PRD_DIR`** — absolute directory containing **`PRD_FILE`** (`dirname`). Used to resolve **`monorepoRoot`** and other PRD-relative paths.
- **`RALPH_DIR`** = `{WORKSPACE_ROOT}/.ralph` — holds **`progress.md`**, **`guardrails.md`**, **`.last-branch`**, and **`archive/`** (not necessarily the PRD).
- **`WORKSPACE_ROOT`** — Cursor workspace root.

**Before anything else:** ensure **`RALPH_DIR`** exists (`mkdir -p .ralph`) so **`progress.md`** and friends have a home. **No separate `.log` files** — durable review artifacts are **`PRD_FILE`**, **`{RALPH_DIR}/progress.md`**, optional **`{RALPH_DIR}/guardrails.md`**, **`.last-branch`**, and **`archive/`**.

**Execution pattern:** **path injection** for monorepo root, default app folder, and **story work directory**; **fresh subagent context** per Task. **Scheduling:** see **Parallel scheduling** — up to **`max_parallel`** (default **3**) implementation subagents per wave when the PRD encodes dependencies; otherwise **one** story at a time by **`priority`**. If a subagent’s **context is nearly full**, run an **agent rotation step** (handoff in **`progress.md`**, new subagent—same story). **Completion** only when **every** `userStories[]` has `passes: true`.

## Equivalences (this command as the loop driver)

| Concern | Cursor command behavior |
|---------|-------------------------|
| **Agent process** | **Main thread** selects **ready** stories, verifies outcomes, updates **`PRD_FILE`** (orchestrator-owned writes). **Up to `max_parallel` (default 3)** implementation subagents may run **concurrently** when **Parallel scheduling** allows; otherwise **one** at a time. |
| **Stop / complete signal** | **Orchestrator** stops only after re-reading **`PRD_FILE`** and confirming **zero** stories with `passes: false`. |
| **Ralph data location** | **`RALPH_DIR`** = `{WORKSPACE_ROOT}/.ralph` for **progress**, **guardrails**, **archive**, **`.last-branch`** (see **Canonical artifacts**). |
| **PRD path** | **`PRD_FILE`** = whatever the **user attached or pathed** in chat. **Never** invent or recreate `prd.json`; use only that file for PRD reads/writes. |
| **Prompt template** | **`ralph-main/prompt.md`** under `WORKSPACE_ROOT`. Missing → stop. |
| **Run / error / rotation trace** | **Everything** goes into **`{RALPH_DIR}/progress.md`**: iteration entries, **rotation checkpoints**, and **`## Orchestrator notes`** (blocks, verification failures, session cap). No other log files. |
| **Sleep between iterations** | **Pause ~2 seconds** before launching the next subagent. |
| **Retryable API / tool failure** | **Wait ~5 seconds**, re-delegate the same story **once**; if it fails again, **append** an entry under **`## Orchestrator notes`** in `progress.md` and **ask the user**. |
| **Guardrails** | **`{RALPH_DIR}/guardrails.md`** — inject when non-empty; disable by clearing/removing the file. |
| **Branch change archive** | If `{RALPH_DIR}/.last-branch` differs from **`branchName`** in **`PRD_FILE`**, create `{RALPH_DIR}/archive/<YYYY-MM-DD>-<sanitized-branch>/`, copy **`PRD_FILE`** and **`{RALPH_DIR}/progress.md`** into it, **reset** `{RALPH_DIR}/progress.md` to the Ralph empty template (see `ralph-main/prompt.md`), then write current `branchName` to `.last-branch`. If `branchName` is empty, skip archive. |
| **Incomplete story count** | `passes === false`. Use `jq` when available; otherwise count manually. |
| **`max_stories` cap** | Default **10** story delegations per invocation unless overridden. At cap: **append** to **`## Orchestrator notes`** in `progress.md`, list remaining ids in chat, stop. |
| **`max_parallel` cap** | Default **3** concurrent implementation subagents **per wave** when parallel scheduling is active (see **Parallel scheduling**). Does not apply when the PRD has no dependency edges (sequential legacy mode). |
| **PR branch** | **`branchName`** from **`PRD_FILE`**; **`git HEAD` at `GIT_ROOT`** must match before each delegation. **`GIT_ROOT`** is the **real** repository root for the **current story’s execution** (see **Git root resolution**) — **not** assumed to be `MONOREPO_ABS` or `WORKSPACE_ROOT` (those may lack a `.git` directory). |
| **Context reset** | **Agent rotation:** subagent writes a **Rotation checkpoint** block in `progress.md`, returns **`outcome: rotate`**; orchestrator starts a **continuation** subagent (same story). |

## Inputs (user provides)

1. **`PRD_FILE`** — **Required.** Attach or `@`-reference the existing `prd.json` (or equivalent path). The orchestrator uses **that path only** for the PRD; it does **not** create or duplicate the file.
2. **`max_stories`** (optional) — Session cap; default **10**.
3. **`max_parallel`** (optional) — Max concurrent implementation subagents per wave when parallel mode applies; default **3**.

If **`PRD_FILE`** is missing, unreadable, or not JSON, **stop** and ask the user to attach the correct file — **do not** fabricate a PRD.

## Parallel scheduling (`max_parallel`, `dependsOn`)

**`max_parallel`** (default **3**): upper bound on how many implementation subagents the orchestrator may **start at once** in a single wave.

**`dependsOn`** (optional on each `userStories[]` item): array of story **`id`** strings that must have **`passes: true`** before that story is **ready**. **Missing or omitting `dependsOn` means `[]`** (no prerequisites).

**When to run in parallel**

- Compute **ready** stories: `passes === false` and every **`dependsOn`** id has `passes === true`.
- **Parallel mode is ON** when **at least one** story has a **non-empty** **`dependsOn`** array (the PRD encodes a DAG). Then each wave: pick up to **`max_parallel`** ready stories (tie-break with **`priority`**, then document order), resolve **`GIT_ROOT`** / branch **per story**, launch subagents, **wait for the wave to finish**, verify, update **`passes`** **sequentially** on **`PRD_FILE`** (no concurrent writes to the PRD).
- **Parallel mode is OFF** (legacy): if **no** story has **`dependsOn`** defined **or** every **`dependsOn` is `[]`**, run **one** ready story per cycle — lowest **`priority`** among incomplete (same as classic Ralph). **`max_parallel`** does not increase concurrency in this mode (effective **1**).

**Git caution:** parallel implementation on the **same** **`GIT_ROOT`** / **`branchName`** risks merge conflicts; prefer **`dependsOn`** to serialize same-repo work, or reduce **`max_parallel`**, or use per-story branches (out of scope unless added to PRD).

**`max_stories`** counts **delegations** (each subagent launch), not waves — tune both if needed.

## Canonical artifacts (under `WORKSPACE_ROOT`)

| Artifact | Path | Role |
|----------|------|------|
| Ralph folder | `.ralph/` → **`RALPH_DIR`** | Create if missing (for progress / guardrails / archive). |
| PRD | **`PRD_FILE`** (user-given) | **Agent + user** — stories, `passes`, `branchName`, paths. **Not** auto-created. |
| Progress | `{RALPH_DIR}/progress.md` | **Agent + user** — patterns, iteration log, rotation checkpoints, orchestrator notes. |
| Guardrails | `{RALPH_DIR}/guardrails.md` | **Agent** — optional injected rules. |
| Branch pointer | `{RALPH_DIR}/.last-branch` | **Orchestrator** — archive trigger. |
| Archive | `{RALPH_DIR}/archive/` | **User** — prior branch snapshots. |

**`PRD_DIR`** = directory of **`PRD_FILE`** — used for **`monorepoRoot`** resolution (see **Path resolution**). It may or may not equal **`RALPH_DIR`**.

**`progress.md` structure (required sections):**

1. **`# Ralph progress`**, **`## Codebase Patterns`**, **`## Iteration log`** — per `ralph-main/prompt.md`.
2. **`## Orchestrator notes`** — append-only, dated lines or `### YYYY-MM-DD HH:MM — orchestrator` bullets for: branch/checkout blocks, verification failures, retry exhaustion, **`max_stories`** / **`max_parallel`** / merge conflicts, rotation safety cap, or anything the user must see when reopening the repo.

If **`progress.md`** is missing, create it using the same empty template as `ralph-main/ralph.sh` / `prompt.md` (title, Codebase Patterns placeholder, Iteration log, plus empty **`## Orchestrator notes`**).

**Instruction source:** Subagents follow **`ralph-main/prompt.md`**. Missing file → stop.

## Agent rotation step (context window)

**Goal:** Avoid context truncation. Preserve state in **`progress.md`** only; no separate rotation log file.

### Subagent: watch context

- **Watch** token/context usage (Cursor UI, warnings, or heuristics: huge reads, many tool rounds without finishing).
- **Threshold:** ~**75–85%** of typical window or any “near limit” signal → **rotate** before hard failure.
- **Before returning `rotate`:**
  - **Commit** what is green (conventional commit); if tests red, document uncommitted paths in the checkpoint.
  - **Append** to **`{RALPH_DIR}/progress.md`** under **`## Iteration log`** a subsection:

```markdown
### YYYY-MM-DD — [Story ID] — Rotation checkpoint (context handoff)
- **Context:** (e.g. ~80% estimated)
- **git:** **`GIT_ROOT`** (repo toplevel), short SHA, branch name
- **Files touched:** …
- **Commands run:** …
- **Acceptance criteria:** done vs remaining (checklist)
- **Next steps:** (numbered)
- **Pitfalls:** …
---
```

  - The next agent **must** find this block by story `id` (latest checkpoint for that id wins).

- **Return** **`outcome: rotate`** and a one-line pointer: “handoff in `progress.md` rotation checkpoint for [Story ID].”

### Orchestrator: on `outcome: rotate`

1. **Do not** set `passes: true`; **do not** advance to the next PRD story.
2. **Re-verify** `git -C "$GIT_ROOT" branch --show-current` matches `branchName` (recompute **`GIT_ROOT`** for this story if needed—same rules as **Git root resolution**).
3. **Continuation task packet** — same story; instruct subagent to read the **latest Rotation checkpoint** for that `id` in `progress.md`.
4. **Pause ~2s**, launch new subagent.
5. **Safety cap:** **>5** rotations for the same story without `passes: true` → **append** to **`## Orchestrator notes`**, **ask the user**.

### Continuation task packet

Same as **Subagent task packet**, plus: continuation after rotation; read **latest Rotation checkpoint** for this story in `{RALPH_DIR}/progress.md`; continue from **Next steps**; keep monitoring context.

## Orchestrator responsibilities (main thread)

1. **Ensure `RALPH_DIR` exists** and **`progress.md`** exists (create from template if missing).
2. **Read** `PRD_FILE` and `{RALPH_DIR}/progress.md` (Codebase Patterns → Iteration log → latest rotation checkpoints / Orchestrator notes as needed).
3. **Branch archive handoff** (equivalences table) when `{RALPH_DIR}/.last-branch` ≠ `branchName` from **`PRD_FILE`**.
4. **Empty `branchName`:** if missing/empty/`null` in **`PRD_FILE`**, **append** to **`## Orchestrator notes`**, stop until fixed or user overrides.
5. **Resolve** `MONOREPO_ABS` and `IMPL_ABS` from **`PRD_FILE`** (**Path resolution** — no story-specific dir yet).
6. **Select** work for this wave per **Parallel scheduling**: **one** story (lowest **`priority`** among incomplete) when parallel mode is **OFF**; otherwise up to **`max_parallel`** (default **3**) **ready** stories. For **each** selected story, compute **`STORY_WORK_ABS`** (path-resolution table).
7. **Per story in the wave — `GIT_ROOT`:** directory for `git fetch` / `checkout` / `branch` (**not** assumed to be `WORKSPACE_ROOT`).
   - **Primary:** `git -C "<STORY_WORK_ABS>" rev-parse --show-toplevel`
   - **Else:** try **`IMPL_ABS`**, then **`MONOREPO_ABS`**
   - **If all fail:** **append** **`## Orchestrator notes`**, stop or ask the user.
8. **Per story — branch alignment at that story’s `GIT_ROOT`:** same rules as before (`branchName`, dirty worktree, etc.).
9. **Launch** one subagent per selected story (≤ **`max_parallel`**), each packet including its own **`STORY_WORK_ABS`** and **`GIT_ROOT`**. **Wait for the full wave** to finish before starting the next wave (including **rotate** continuations for any story in the wave).
10. **After** the wave returns:
   - For each story: **`outcome: rotate`** → handle rotation, then finish that story’s continuation before counting the wave done (or serialize rotations if needed).
   - Verification failure → **`## Orchestrator notes`**, retry or escalate.
   - Apply **`passes`** updates to **`PRD_FILE`** **one at a time** (no concurrent PRD writes).
   - Confirm **`PRD_FILE`** / **`{RALPH_DIR}/progress.md`** per checklist.
11. **Pause ~2s**, **re-read** **`PRD_FILE`**, **repeat from step 5** until done, **`max_stories`**, or hard stop.
12. **Never** claim complete unless every `userStories[]` has `passes: true`.

**Orchestrator tools:** read-only tools + **`git -C "$GIT_ROOT"`** (fetch/checkout/branch) for alignment only. **Do not** implement application code in the orchestrator turn.

## Path resolution (each iteration)

**`PRD_DIR`** = absolute directory containing **`PRD_FILE`**. Read JSON from **`PRD_FILE`**:

- **`monorepoRoot`** — path from **`PRD_DIR`** to the folder that **contains** app repos. Default **`".."`** if absent (e.g. PRD under `.ralph/` → monorepo is parent). If the PRD already lives at the monorepo root, set **`monorepoRoot`** to **`"."`** in the JSON (do not change the file for that—use what the user gave).
- **Default implementation folder:** `implementationPath` || `project` || `"."`.

**`MONOREPO_ABS`** = canonical `PRD_DIR/monorepoRoot`. **`IMPL_ABS`** = `MONOREPO_ABS/<implementationPath|project|.>`. If `IMPL_ABS` missing, **append** one line to **`## Orchestrator notes`** and warn in the task packet.

**Story `repo` / `package`:**

| `repo` (or `package`) | `STORY_WORK_ABS` |
|------------------------|------------------|
| `TBD` | `IMPL_ABS` |
| `ai-cm` (or PRD monorepo-root label) | `MONOREPO_ABS` |
| other | `MONOREPO_ABS/<repo>` |

**`GIT_ROOT` (per iteration):** resolved **after** `STORY_WORK_ABS` exists — see orchestrator step 7. All **branch** alignment and **commit** operations for the feature branch use **`GIT_ROOT`** (the repo that contains the story’s files), not necessarily `WORKSPACE_ROOT` or `MONOREPO_ABS`.

**Injected block for the subagent:**

- **PRD file (`PRD_FILE`):** absolute path — **only** this file for PRD updates (`passes`, etc.); **do not** write a different `prd.json`.
- **Ralph working files (`RALPH_DIR`):** absolute path — **`progress.md`**, **`guardrails.md`** here only (no `.log` files).
- **Git repository root (`GIT_ROOT`):** absolute path — run **`git status`**, **`git checkout`**, **`git commit`** for **this story** from here (or with `git -C "$GIT_ROOT"`). **`branchName`** must match **`git -C "$GIT_ROOT" branch --show-current`** before and after edits.
- **Monorepo / implementation / story work directories:** `MONOREPO_ABS`, `IMPL_ABS`, `STORY_WORK_ABS` — for **`npm`**, file paths, and tooling as in `ralph-main/prompt.md`.

**Guardrails:** prepend `{RALPH_DIR}/guardrails.md` when non-empty.

## Subagent task packet (copy/fill per story)

1. **Role:** One story; **`ralph-main/prompt.md`**.
2. **Resolved paths** (absolute).
3. **Guardrails** if present.
4. **Current story** (structured).
5. **Tasks:**
   - **Context / rotation:** on limit, write **Rotation checkpoint** in `progress.md`, return **`outcome: rotate`**.
   - **Git:** use **`GIT_ROOT`** from the injected block for **all** branch checks and **repository** git operations. Confirm `git -C "$GIT_ROOT" branch --show-current` === **`branchName`** before edits. Do **not** assume `WORKSPACE_ROOT` or `MONOREPO_ABS` is a git root.
   - **Story work directory** for **`npm test`**, typecheck, and most file edits; **`GIT_ROOT`** may equal `MONOREPO_ABS` or be an ancestor—follow the repo’s layout.
   - Implement story; tests + typecheck; conventional commits.
   - Update **`PRD_FILE`** only for PRD fields (`passes`, etc.); `passes: true` when fully done.
   - **`{RALPH_DIR}/progress.md`:** full **Iteration log** entry when story **completes**; **Rotation checkpoint** when rotating; **Codebase Patterns** when needed; **`AGENTS.md`** per `prompt.md`.
6. **Return:** `outcome` = `completed` \| `rotate` \| `blocked` \| `failed`; summary for orchestrator (handoff is **in `progress.md`**, not chat-only).

## Verification checklist (after each subagent)

- [ ] **`git -C "$GIT_ROOT" branch --show-current`** matches **`branchName`** (re-resolve **`GIT_ROOT`** if the story’s work dir changed).
- [ ] **`outcome: rotate`:** latest **Rotation checkpoint** for that story `id` exists in `progress.md`; continuation queued.
- [ ] **`outcome: completed`:** `passes` in **`PRD_FILE`** and **Iteration log** in **`{RALPH_DIR}/progress.md`** per `prompt.md`.
- [ ] Failures recorded under **`## Orchestrator notes`** when the user must act; do not advance the story until resolved or directed.

## When finished

- **All `passes: true`:** Point the user to **`PRD_FILE`** and **`{RALPH_DIR}/progress.md`**.
- **Stopped early:** Same + **`## Orchestrator notes`** for blockers and remaining stories.

## References (orchestrator)

- @ralph-main/prompt.md — implementation contract and `progress.md` format
- @ralph-main/AGENTS.md — Ralph + ai-cm context
- @.cursorrules — repo-wide rules for handlers, DAL, tests, commits
