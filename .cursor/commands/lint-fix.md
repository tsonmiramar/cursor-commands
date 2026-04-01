# Lint and Fix Code

## Overview

Run the repo’s lint and type-check scripts, fix any issues (using subagents for multi-file work), and optionally commit. Can also be used to analyze the current file for linting issues and fix them according to the project’s coding standards.

## Subagent usage

- **Run scripts and fix errors**: After running `lint:fix` and `tslint`, if there are any remaining errors, use a **subagent** (e.g. `generalPurpose` or `shell`) to fix all linting/type errors across the repo and commit with a conventional message. Do not attempt to fix repo-wide errors entirely inline when many files are affected.
- **Identify and apply fixes**: For repo-wide or multi-file lint fixes, use a **subagent** to identify issues and apply fixes. For a single file, the agent may do it inline.

## Steps

1. **Run repo lint and type-check**
   - Determine the relevant repo (current workspace or the one containing the branch) and open its `package.json`.
   - Run the **lint fix** and **tslint** scripts defined there (e.g. `npm run lint:fix`, `npm run tslint`). Use the exact script names from that repo’s `package.json`.
   - If there are any lint or type errors: use a **subagent** to fix all linting/type errors across the repo, then commit the changes with a **conventional commit** (e.g. `fix(APP-XXXX): lint and type fixes`; ticket must match branch when used before creating an MR). Do not proceed until lint and tslint pass and any fixes are committed.
2. **Identify linting issues**
   - (For multi-file or repo-wide scope, use a **subagent** to perform this step.)
   - Code formatting and style consistency
   - Unused imports and variables
   - Missing semicolons or proper indentation
   - Best practice violations
   - Type safety issues
3. **Apply fixes**
   - (For multi-file or repo-wide scope, use a **subagent** to apply fixes.)
   - Fix formatting and style issues
   - Remove unused imports and variables
   - Add missing semicolons or correct indentation
   - Apply best practice corrections
   - Fix type safety issues
   - Explain what changes were made

## Lint and Fix Code Checklist

- [ ] Identified all code formatting and style issues
- [ ] Identified unused imports and variables
- [ ] Identified missing semicolons or indentation issues
- [ ] Identified best practice violations
- [ ] Identified type safety issues
- [ ] Applied all formatting and style fixes
- [ ] Removed unused imports and variables
- [ ] Fixed indentation and added missing semicolons
- [ ] Applied best practice corrections
- [ ] Fixed type safety issues
- [ ] Explained what changes were made
