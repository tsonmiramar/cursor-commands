# Code Review

## Overview

Review changes for functionality, maintainability, and security. Always run **multiple parallel sub-agents** to examine the code from different angles (security, logic/functionality, business-logic/acceptance-criteria, compliance/code quality). Deliver feedback as a **structured list of comments** (File, Line, Position, Comment) with positions taken from the diff so inline GitLab API calls do not return 400.

**Initial review** proposes new feedback. **Re-review** checks whether **existing MR discussions** (inline or general) are addressed on the current head, reports status per thread, and—after user confirmation—**resolves** threads that are fully addressed (see **Re-review**).

## Optional: GitLab MR by URL

If the user provides an MR URL (e.g. `https://gitlab.com/group/project/-/merge_requests/123`):

1. Parse project path and MR IID.
2. Fetch MR data once with `glab mr view <iid> -R <project> -F json` and store it (for `diff_refs.base_sha`, `diff_refs.head_sha`, and MR description).
3. Fetch the MR patch once with `glab mr diff <iid> -R <project>` and store it (for all inline diff hunk positioning).
4. Do not call `glab mr view` or `glab mr diff` again; reuse the stored MR JSON/diff for checkout and for all sub-agents.
5. For **re-review**, also fetch MR discussions **once** and store them (see **Re-review**). Do not refetch for sub-agents; reuse the same JSON.

Otherwise use the current branch and working tree. Re-review without an MR URL is limited to local comparison unless the user points to exported discussion data or an MR URL.

## Optional: JIRA issue by URL

If the content being reviewed contains a JIRA issue URL (e.g. `https://your-jira-domain/browse/KEY-123`), attempt to fetch the issue details using the `acli` command line before starting the review. Use `acli jira workitem view KEY-123` command and incorporate the summary, description, and relevant fields into your understanding of the change.

### Orchestrator Agent Responsibilities
1. Worktree setup (autonomous): `cd` into the local checkout of the repository that owns the MR (the one specified by `-R <project>`). Use the stored MR JSON to read `diff_refs.base_sha` and `diff_refs.head_sha`. Create two detached worktrees (so base + head are available simultaneously) at stable paths like `<tmp>/code-review-base` and `<tmp>/code-review-head` using `git worktree add --detach -f <base_path> <base_sha>` and `git worktree add --detach -f <head_path> <head_sha>`. Keep the original checkout untouched.
   - Practical dependency optimization (npm only): run `npm ci` only in `<head_path>`.
   - If `package.json` and `package-lock.json` did not change between `base_sha..head_sha`, then avoid reinstalling deps in `<base_path>` by symlinking:
     - remove `<base_path>/node_modules` (if it exists)
     - `ln -s <head_path>/node_modules <base_path>/node_modules`
2. Spawn parallel analysis sub-agents (security, logic/functionality, business-logic/acceptance-criteria, compliance/code quality, plus deeper review angles). All sub-agents must receive the same MR diff + description; inline comment positions must come from diff hunks only.
   Security sub-agent: identify security/data-integrity risks, unsafe trust boundaries, injection/privacy issues, and propose mitigations.
   Logic/functionality sub-agent: verify the change’s intended behavior, edge cases, error handling, and that the wiring between functions/handlers/middlewares is consistent.
   Business-logic/acceptance-criteria sub-agent: cross-check the Jira requirements (or MR description) against the implementation and tests; flag any missing acceptance criteria coverage and propose how to meet them.
   Compliance/code-quality sub-agent: check TypeScript/type safety, schema/validation correctness, code style consistency, and whether tests/docs were updated appropriately.
   Performance & scalability sub-agent: look for inefficient loops/batches, potential N+1 queries, contention/hot paths, and suggest targeted improvements.
   Reliability & resilience sub-agent: review retry/backoff/timeouts/idempotency, and how failures are handled (including partial failures).
   Observability sub-agent: verify logs/metrics/tracing are sufficient, and ensure sensitive data is not emitted.
   API contract & schema evolution sub-agent: check backward compatibility, request/response correctness, and how schemas/types change across versions.
   DAL/DB integrity & migrations sub-agent: validate persistence expectations (constraints/indexes), and whether DAL/DB changes are aligned with runtime behavior.
   Test strategy (integration/E2E) sub-agent: identify gaps beyond unit tests and propose pragmatic integration/E2E coverage.
   Deployment & configuration risk sub-agent: review environment variables, defaults, feature flags, safe rollout considerations, and runtime safety.
   Maintainability & architecture sub-agent: assess separation of concerns, code duplication, and whether the change fits the project’s existing patterns.
   Sub-agents should read code from:
   - `<head_path>` for "what changed"
   - `<base_path>` for "what it used to do" (for better comparison and fewer false positives)
3. Collect and normalize all findings into a single comment table; gate on user confirmation before any GitLab API calls.
4. Cleanup: remove the temporary worktrees (`git worktree remove --force <base_path>` and `<head_path>`) after analysis/collection, unless cleanup would interfere with the user’s ongoing work.

## Re-review (addressed comments & resolve threads)

Use when the user asks to **re-review**, **check if feedback is fixed**, **resolve addressed threads**, or similar, on a GitLab MR.

### When to run

- Treat as re-review if the user explicitly requests it **or** the MR already has open discussions and the user is iterating after a prior review.
- Combine with a normal review pass: after threading existing feedback, still run sub-agents on the **current** diff for **new** issues (optional but recommended unless the user wants “resolve only”).

### Fetch discussions (once)

After `glab mr view` (for project id / path and `diff_refs`), fetch all discussions:

- Prefer `glab api` against [Merge request discussions](https://docs.gitlab.com/ee/api/discussions.html#list-project-merge-request-discussions), e.g. `GET /projects/:id/merge_requests/:merge_request_iid/discussions` (paginate if needed).
- Store each thread: `id` (discussion id), `resolved`, notes (author, body, `position` / file paths if inline), and whether it is a **diff note** vs **MR-level** note.

### Verify each open thread

For each discussion where `resolved` is false (or the user asked to re-check resolved threads—then include those too):

1. **Understand the ask** from the first note (and any follow-ups); map to files/lines or behavior.
2. **Inspect current head** (`<head_path>` or latest `glab mr diff`): confirm the change satisfies the feedback (code, tests, config, docs as applicable).
3. **Classify**:
   - **Addressed** — feedback fully implemented; no remaining gap.
   - **Partially addressed** — some improvement; thread should stay open with a short note why (optional: draft a reply, do not post without confirmation).
   - **Not addressed** — no meaningful change; leave open.
   - **Obsolete** — e.g. code path removed or requirement dropped; safe to resolve with a brief rationale.

### Output: re-review table

Deliver a table separate from new findings:

| Discussion ID | File / scope | Original ask (summary) | Status | Rationale (brief) |
| ------------- | ------------ | ---------------------- | ------ | ------------------- |
| `abc123…`     | `src/foo.ts` | Add rate limit         | Addressed | Limit enforced in middleware; tests added. |

Optional column: **Resolve?** (`yes` / `no` / `reply only`) for threads the user might want to handle manually.

### Resolving threads (GitLab API, after confirmation)

1. Show the re-review table and list **discussion ids proposed for resolution**.
2. Ask: _“Confirm to resolve these threads on the MR, or say which to skip / reply to instead.”_ Do not resolve until confirmed.
3. Auth: `GITLAB_TOKEN` (or `PRIVATE-TOKEN`). If unset, stop and tell the user.
4. For each confirmed thread, call the API to resolve the discussion, e.g. [Resolve a merge request thread](https://docs.gitlab.com/ee/api/discussions.html#resolve-a-merge-request-thread): `PUT /projects/:id/merge_requests/:merge_request_iid/discussions/:discussion_id` with body `{"resolved": true}` (or the form documented for your GitLab version).
5. On failure for one id: report `(discussion_id, response)`, continue or stop per user preference; do not assume partial state without checking.
6. If the user wants a **closing reply** on a thread before resolve, post a note on that discussion first (same discussions API / notes), then resolve—only after confirmation.

### Resolve-only vs full re-review

- **Resolve-only:** fetch discussions → verify → table → confirm → resolve. Skip spawning all review sub-agents unless the user wants a fresh pass.
- **Full re-review:** discussions pass **plus** parallel sub-agents on the latest diff; merge “threads to resolve” with “new comments to post” into one confirmation step (two tables or one combined plan).

## Steps

1. **Classify:** initial review, re-review, or both (see **Re-review**).
2. Orchestrate: setup base/head worktrees when using MR SHAs; fetch and store MR diff + (for GitLab re-review) discussions once.
3. **Re-review path:** verify each open thread against head; build re-review table; optionally run sub-agents for new findings.
4. **Initial review path:** run sub-agents in parallel; build comment table.
5. Verify & output: use the **Review Checklist** (and re-review status); gate **posting new comments** and **resolving threads** on user confirmation.

## Review Checklist

- [ ] **Functionality:** Behavior matches requirements; edge cases and errors handled.
- [ ] **Code quality:** Clear structure; no duplication or dead code; tests/docs updated.
- [ ] **Security:** No obvious vulnerabilities; inputs validated, outputs sanitized; sensitive data handled.
- [ ] **Other:** Architecture and performance considered; alternatives or extra tests noted.

**Re-review checklist**

- [ ] **Threads:** Every open discussion classified (addressed / partial / not addressed / obsolete).
- [ ] **Evidence:** Rationale ties to concrete lines or behavior on current head.
- [ ] **Resolve:** User confirmed before any `resolved: true` API calls; failures reported per thread.

## Posting comments to the PR (GitLab)

Resolving threads that prior review opened is covered in **Re-review** (confirmation + API), not here.

When the user wants **new** comments on the MR:

1. **Comment list** — Return feedback as a table: **File** (path or `(MR-level)`), **Line** (in diff, or `—` for MR-level), **Position** (added → `new_line` only; removed → `old_line` only; unchanged-in-hunk → both; omit for MR-level), **Comment** (short, friendly, actionable).  
   **Positions from diff only:** Parse the MR diff; attach inline comments only to lines in hunks (added/removed/changed). Use hunk headers (e.g. `@@ -a,b +c,d @@`) for line numbers. Comments on lines outside hunks cause 400.

   Example:

   | File                                        | Line | Position               | Comment                                                 |
   | ------------------------------------------- | ---- | ---------------------- | ------------------------------------------------------- |
   | (MR-level)                                  | —    | —                      | Clear fix; early return helps.                          |
   | `src/components/MakeCalls/CallPatients.tsx` | 142  | added, `new_line`: 142 | Add `data-testid="call-action-redial"` for consistency. |
   | (MR-level)                                  | —    | —                      | A test for the failure case would help.                 |

2. **Confirm** — Show the list and ask: _"Confirm to post, or say what to change."_ Do not post until confirmed.

3. **Post (GitLab API)** — Auth: `GITLAB_TOKEN` (e.g. from `~/.config/glab-cli/config.yml`). If unset, tell the user and do not post.  
   `POST .../projects/:id/merge_requests/:merge_request_iid/discussions` with `PRIVATE-TOKEN` or `Authorization: Bearer`.  
   **MR-level:** body only. **Inline:** body + `position`; get `base_sha`, `head_sha`, `start_sha` from MR JSON `diff_refs`. `position.position_type = "text"`, `new_path`/`old_path`. Line rules: **added** → `position[new_line]` only; **removed** → `position[old_line]` only; **unchanged in hunk** → both. **Multi-line:** needs `line_code` and `line_range` per [GitLab Discussions API](https://docs.gitlab.com/ee/api/discussions.html#line-code). Use form-encoded for position.  
   If inline returns 400: stop, report (file, line, response), do not post rest. Then post in order and reply with note URLs or MR link.
