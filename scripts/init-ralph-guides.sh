#!/usr/bin/env bash
# Initialize `.ralph/guides/` in a project by copying bundled Ralph planning guides
# from this repository. Safe to re-run; overwrites guide files in the destination.
#
# Usage:
#   ./scripts/init-ralph-guides.sh              # current directory = project root
#   ./scripts/init-ralph-guides.sh /path/to/repo
#   ./scripts/init-ralph-guides.sh --dry-run .

set -euo pipefail

DRY_RUN=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h | --help)
      sed -n '2,9p' "$0" | tr -d '#'
      exit 0
      ;;
    *) ARGS+=("$arg") ;;
  esac
done

TARGET="${ARGS[0]:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$REPO_ROOT/ralph/guides"

if [[ ! -d "$SOURCE" ]]; then
  echo "error: bundled guides not found at $SOURCE" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "error: project root is not a directory (create it first): $TARGET" >&2
  exit 1
fi

DEST="$(cd "$TARGET" && pwd)/.ralph/guides"

shopt -s nullglob
files=("$SOURCE"/*.md)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "error: no .md files in $SOURCE" >&2
  exit 1
fi

if $DRY_RUN; then
  echo "Would create: $DEST"
  for f in "${files[@]}"; do
    echo "Would copy: $(basename "$f")"
  done
  exit 0
fi

mkdir -p "$DEST"
for f in "${files[@]}"; do
  cp "$f" "$DEST/"
  echo "Installed $(basename "$f") -> $DEST/"
done
echo "Ralph guides initialized at $DEST"
