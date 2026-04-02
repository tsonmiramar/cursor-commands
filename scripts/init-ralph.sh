#!/usr/bin/env bash
# Initialize Ralph workspace assets in a target project:
#   - .ralph/guides/     (planning guides from this repo)
#   - .cursor/commands/  (ralph-orchestrate + ralph-initiate-setup-prd)
#   - .ralph/progress.md (stub if missing)
# Safe to re-run: overwrites guides and command files; does not overwrite existing progress.md.
#
# Usage:
#   ./scripts/init-ralph.sh              # current directory = project root
#   ./scripts/init-ralph.sh /path/to/repo
#   ./scripts/init-ralph.sh --dry-run .

set -euo pipefail

DRY_RUN=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h | --help)
      sed -n '2,12p' "$0" | tr -d '#'
      exit 0
      ;;
    *) ARGS+=("$arg") ;;
  esac
done

TARGET="${ARGS[0]:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GUIDES_SRC="$REPO_ROOT/ralph/guides"
CMD_SRC="$REPO_ROOT/.cursor/commands"
PROGRESS_TMPL="$REPO_ROOT/ralph/progress.md.template"

RALPH_CMDS=(
  "ralph-orchestrate.md"
  "ralph-initiate-setup-prd.md"
)

if [[ ! -d "$GUIDES_SRC" ]]; then
  echo "error: bundled guides not found at $GUIDES_SRC" >&2
  exit 1
fi

if [[ ! -d "$CMD_SRC" ]]; then
  echo "error: .cursor/commands not found at $CMD_SRC" >&2
  exit 1
fi

for c in "${RALPH_CMDS[@]}"; do
  if [[ ! -f "$CMD_SRC/$c" ]]; then
    echo "error: missing command file $CMD_SRC/$c" >&2
    exit 1
  fi
done

if [[ ! -f "$PROGRESS_TMPL" ]]; then
  echo "error: progress template not found at $PROGRESS_TMPL" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "error: project root is not a directory (create it first): $TARGET" >&2
  exit 1
fi

ROOT="$(cd "$TARGET" && pwd)"
DEST_GUIDES="$ROOT/.ralph/guides"
DEST_CMDS="$ROOT/.cursor/commands"
RALPH_DIR="$ROOT/.ralph"
PROGRESS_FILE="$RALPH_DIR/progress.md"

shopt -s nullglob
guide_files=("$GUIDES_SRC"/*.md)
shopt -u nullglob

if [[ ${#guide_files[@]} -eq 0 ]]; then
  echo "error: no .md files in $GUIDES_SRC" >&2
  exit 1
fi

if $DRY_RUN; then
  echo "Would create: $DEST_GUIDES"
  for f in "${guide_files[@]}"; do
    echo "Would copy guide: $(basename "$f")"
  done
  echo "Would create: $DEST_CMDS"
  for c in "${RALPH_CMDS[@]}"; do
    echo "Would copy command: $c"
  done
  if [[ -f "$PROGRESS_FILE" ]]; then
    echo "Would skip (exists): $PROGRESS_FILE"
  else
    echo "Would create: $PROGRESS_FILE (from template)"
  fi
  exit 0
fi

mkdir -p "$DEST_GUIDES"
for f in "${guide_files[@]}"; do
  cp "$f" "$DEST_GUIDES/"
  echo "Installed guide $(basename "$f") -> $DEST_GUIDES/"
done

mkdir -p "$DEST_CMDS"
for c in "${RALPH_CMDS[@]}"; do
  cp "$CMD_SRC/$c" "$DEST_CMDS/"
  echo "Installed command $c -> $DEST_CMDS/"
done

mkdir -p "$RALPH_DIR"
if [[ -f "$PROGRESS_FILE" ]]; then
  echo "Skipped existing $PROGRESS_FILE"
else
  SESSION_DATE=$(date +%Y-%m-%d)
  sed "s/__SESSION_DATE__/$SESSION_DATE/" "$PROGRESS_TMPL" >"$PROGRESS_FILE"
  echo "Created $PROGRESS_FILE"
fi

echo "Ralph workspace initialized: guides, Cursor commands, progress (if new)."
