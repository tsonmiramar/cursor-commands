## Address PR Comment

### Purpose

Handle outstanding reviewer feedback on a GitLab merge request: understand the comments, apply any required code changes, draft and confirm replies with the user, then **run `/create-commits` in the correct repo and branch** for any new code before posting replies via the GitLab API.

### Inputs and MR discovery

- **Required input**
  - Either:
    - A **merge request URL**, e.g. `https://gitlab.com/group/project/-/merge_requests/123`, or
    - A **merge request IID** (e.g. `123`), in which case the project is inferred from the current repo’s Git remote.
  - If neither is provided, ask: *"Please provide the merge request URL (e.g. https://gitlab.com/group/project/-/merge_requests/123) or the merge request ID (e.g. 123)."* and stop until the user supplies one.

- **Resolve project, MR, and source branch**
  - If given a URL, parse it to get:
    - Project path: `group/project`
    - MR IID: e.g. `123`
  - Use `glab mr view <iid> -F json` (with `-R <project>` when using a project path) to obtain:
    - `project_id` (or confirm project path)
    - MR **source branch** name (where commits must be made)
    - Other metadata: title, description, author, state, `diff_refs`.
  - If given only an IID, run `glab mr view <iid> -F json` from the correct local repo and let glab infer the project from Git remotes.

- **Fetch discussions and optional diff**
  - Discussions:
    - `glab api projects/<project_id>/merge_requests/<iid>/discussions --paginate`
    - Or use URL‑encoded project path: `projects/group%2Fproject/merge_requests/<iid>/discussions`.
  - Optional diff for context:
    - `glab mr diff <iid> [-R <project>]`

### Workflow

1. **Audit comments**
   - Confirm MR URL or IID is available; if not, prompt and stop.
   - Using `glab`, fetch MR details and discussions.
   - Group threads by file or theme and mark which ones need:
     - **Reply only**, or
     - **Code change + reply**.

2. **Plan resolutions**
   - For each actionable thread, decide:
     - What code edits (if any) are required.
     - What the reply should communicate (high‑level).
   - Map threads to specific files/areas of the codebase so edits and replies stay aligned.

3. **Implement fixes**
   - Apply code changes for threads that require edits, keeping work scoped and incremental.
   - Run relevant tests/linters after non‑trivial changes.
   - Keep a simple mapping of “thread → code edits” to reflect in commits and replies.

4. **Draft replies**
   - For each discussion you plan to respond to, write the **exact reply text** (short, friendly, actionable).
   - **Tone guidelines:**
     - Use natural, conversational language (e.g. "Good call — I switched this to the public URL").
     - Thank reviewers when they catch issues or suggest improvements.
     - When you’ve made a change, briefly explain in plain language what changed.
     - For follow‑ups or deferred work, be honest and concise about timing and reasoning.
     - Avoid robotic one‑word replies like "Acknowledged." or "Done." as standalone sentences.
   - Build a reply table:

     | Discussion (first note excerpt or thread id) | Reply body |
     |---------------------------------------------|------------|
     | &lt;brief context&gt;                         | &lt;text to post&gt; |

5. **Present plan and get confirmation**
   - Show the reply table plus a brief summary of associated code changes (if any).
   - Ask: *"Confirm these replies (and associated code changes) to post to the MR, or tell me what to change (add/remove/edit)."*
   - **Do not post replies or create commits** until the user confirms or updates the plan.

6. **Commit and push code with `/create-commits` (only if there are code changes)**
   - When confirmed and code has changed:
     - From MR details, determine:
       - The **project repo** (local directory corresponding to `group/project`).
       - The MR **source branch** name.
     - Switch to the correct repo and branch before committing:
       - `cd <repo-for-project>`
       - `git checkout <mr-source-branch>`
     - Run the `/create-commits` command **in that repo and branch** so that it:
       - Detects uncommitted changes related to the MR.
       - Creates conventional, incremental commits following project rules (ticket/branch‑scoped messages).
       - Pushes those commits to the MR branch’s remote.
   - If there are no code changes (reply‑only threads), skip this step.

7. **Post replies (GitLab REST API)**
   - After code (if any) is committed and pushed, post replies using the GitLab REST API:
     - Authenticate with `GITLAB_TOKEN` (`PRIVATE-TOKEN: $GITLAB_TOKEN` or `Authorization: Bearer $GITLAB_TOKEN`). If missing, tell the user how to set it and do not post.
     - Use the endpoint to add a note to an existing discussion:
       - `POST https://gitlab.com/api/v4/projects/:id/merge_requests/:merge_request_iid/discussions/:discussion_id/notes`
       - Body JSON: `{ "body": "<reply text>" }`.
     - Use the numeric `project_id` from `glab mr view` or the URL‑encoded project path.
   - Post replies in the order of the confirmed list, then summarize which threads were updated and share the MR link (and discussion/note URLs when useful).

### Response checklist

- [ ] MR URL or MR ID obtained (user prompted if missing)
- [ ] MR details (including project and source branch) and discussions fetched via glab
- [ ] All reviewer comments that need a response identified
- [ ] Required code changes implemented and tested (if applicable)
- [ ] Reply table drafted and **presented to user for confirmation**
- [ ] User confirmed replies and associated code changes (or provided updates)
- [ ] Correct repo and MR source branch identified from MR details
- [ ] `/create-commits` run in the correct repo/branch when there are new code changes, and commits pushed
- [ ] Replies posted via GitLab REST API (with `GITLAB_TOKEN` set)
- [ ] Follow‑up items documented or escalated as needed

# Address PR Comment

## Overview

Process outstanding reviewer feedback on a merge request, apply required fixes, draft clear replies for each comment thread, and, once the user confirms the proposed replies, run `/create-commits` to commit and push any new code changes before posting replies via the GitLab API.

## Required input: MR URL or merge request ID

- **Require either:**
  - A **merge request URL**, e.g. `https://gitlab.com/group/project/-/merge_requests/123`, or
  - A **merge request ID (IID)** only, e.g. `123` (the project is then inferred from the current Git repository’s remote).
- **If neither is provided**, prompt: *"Please provide the merge request URL (e.g. https://gitlab.com/group/project/-/merge_requests/123) or the merge request ID (e.g. 123)."* and do not proceed until the user supplies one.

## Fetching MR context with glab CLI

1. **Resolve project and IID**
   - **If the user gave a URL:** parse it (e.g. `https://gitlab.com/group/project/-/merge_requests/123`) to get **project path** `group/project` and **MR IID** `123`. Use `-R <project>` in glab commands.
   - **If the user gave only an IID:** use that as the MR IID and **do not** pass `-R`; glab will use the current repository’s Git remote to determine the project.

2. **Fetch MR details**  
   - With URL: `glab mr view <iid> -R <project> -F json`  
   - With IID only: `glab mr view <iid> -F json` (run from the project repo).  
   - Use the output for: title, description, author, state, `project_id`, and `diff_refs` (needed for any inline position payloads).

3. **Fetch MR diff** (optional, for context)  
   - With URL: `glab mr diff <iid> -R <project>`  
   - With IID only: `glab mr diff <iid>`  
   - Use when the MR branch is not checked out locally to understand the change set.

4. **List discussions (comments)**  
   - Run: `glab api projects/<project_id>/merge_requests/<iid>/discussions --paginate`  
   - Use the numeric `project_id` from step 2. If not in a Git repo for that project, use the URL-encoded project path: `projects/<encoded_path>/merge_requests/<iid>/discussions` (e.g. `group%2Fproject`).  
   - Each discussion has an `id` (string) and `notes[]` (array of comment objects with `body`, `author`, `system`, `resolved`, etc.).  
   - Focus on unresolved or actionable threads (e.g. skip system notes, already-resolved threads, or threads that need no reply).

## Steps

1. **Sync and audit comments**
   - Ensure MR URL or MR ID is set; if not, prompt and stop.
   - Using glab (as above), pull MR details and list all discussions.
   - Group comments by affected file or theme; note which discussions need a reply (e.g. reviewer questions or change requests).

2. **Plan resolutions**
   - For each thread that needs a response, list: requested code edits (if any), clarifications to give, and any blockers.
   - Decide for each thread: reply text only, or code change + reply.

3. **Implement fixes**
   - Apply code changes for comments that require edits, one thread at a time.
   - Run relevant tests or linters after impactful changes.
   - Stage changes with commits that reference the addressed feedback (e.g. in the commit message).

4. **Draft replies**
   - For each discussion that will get a reply, write the exact reply body (short, friendly, actionable).
   - **Tone: friendly and humanized.** Write as a teammate would in a quick chat:
     - Use a natural, conversational tone (e.g. "Good call — I've switched it to use the public URL" instead of "Done. Updated to use public URL.").
     - Thank the reviewer when they caught something or suggested an improvement (e.g. "Thanks for flagging this", "Good point").
     - For fixes you made: say what you did in plain language; avoid sounding like a changelog (e.g. "I removed the unused function and updated the tests" rather than "Done. Removed unused function. Tests updated.").
     - For follow-up / not done yet: be honest and brief (e.g. "Makes sense — I'll move these types in a follow-up so we don't block this MR" or "I'll add logging here in a follow-up.").
     - Avoid robotic or corporate phrasing: no "Acknowledged.", "Done.", "Will address in follow-up." as standalone sentences. Prefer "Got it", "Done — …", "I'll … in a follow-up" with a short reason or next step.
     - Keep replies concise but warm; one or two short sentences is usually enough.
   - Build a **reply list** in this form:

     | Discussion (first note excerpt or thread id) | Reply body |
     |---------------------------------------------|------------|
     | &lt;brief context&gt;                         | &lt;text to post&gt; |

5. **Present replies and ask for confirmation**
   - **Present the full reply list** to the user in a clear table or list, along with a brief summary of the associated code changes (if any).
   - Ask: *"Confirm these replies to post to the MR, or tell me what to change (add/remove/edit)."*
   - **Do not post any replies or create commits** until the user confirms (or provides an updated list).

6. **Commit and push code changes with `/create-commits` (if needed)**
   - After the user confirms the proposal (replies + code changes), run the `/create-commits` command to:
     - Turn any new or updated code into conventional, incremental commits.
     - Use the appropriate ticket/branch naming per `/create-commits` rules.
     - Push those commits to the correct branch.
   - If there are no code changes (reply-only threads), skip this step.

7. **Post replies after confirmation (GitLab REST API)**
   - Once replies are confirmed and any necessary code changes have been committed and pushed, post each reply using the **GitLab REST API**.
   - **Authentication:** Use the token from the **`GITLAB_TOKEN`** environment variable (e.g. `PRIVATE-TOKEN: $GITLAB_TOKEN` or `Authorization: Bearer $GITLAB_TOKEN`). If `GITLAB_TOKEN` is not set, tell the user to set it (e.g. from `~/.config/glab-cli/config.yml` or a GitLab Access Token with `api` scope) and do not post.
   - **Endpoint to add a reply to an existing thread:**  
     `POST https://gitlab.com/api/v4/projects/:id/merge_requests/:merge_request_iid/discussions/:discussion_id/notes`  
     with body parameter `body` = the reply text.
   - **Project id:** Use the numeric `project_id` from `glab mr view` output, or the URL-encoded project path.
   - **Example (curl):**  
     `curl -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "Content-Type: application/json" -d '{"body":"<reply text>"}' "https://gitlab.com/api/v4/projects/<project_id>/merge_requests/<iid>/discussions/<discussion_id>/notes"`
   - Post replies in the order of the confirmed list. After posting, summarize success and share the MR link or discussion/note URLs.

## Response checklist

- [ ] MR URL or MR ID obtained (user prompted if missing)
- [ ] MR details and discussions fetched via glab
- [ ] All reviewer comments that need a response identified
- [ ] Required code changes implemented and tested
- [ ] Reply list drafted and **presented to user for confirmation**
- [ ] User confirmed replies and associated code changes (or updated list provided)
- [ ] `/create-commits` run for new code changes if necessary and changes pushed to the correct branch
- [ ] Replies posted via GitLab REST API (with `GITLAB_TOKEN` set)
- [ ] Follow-up items documented or escalated as needed
