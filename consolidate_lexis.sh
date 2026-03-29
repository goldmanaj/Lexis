#!/usr/bin/env bash
set -euo pipefail

# Consolidate Lexis project files into a single folder and optionally
# delete redundant template files.
#
# Usage:
#   ./consolidate_lexis.sh [--move|--copy] [--force|-f] [--dry-run] [--all] [--target=/path/to/dir]
#
# Defaults:
#   --move (moves files, which will break Xcode references until you re-add them)
#   --target=/Users/Aaron/Desktop/Company/Lexis
#   --all (move all .swift, .md, and .sh files under the project, excluding common build/VCS folders)
#
# After running with --move, open Xcode and re-add files from the target folder,
# then remove broken references. Finally, Clean Build Folder and rebuild.

TARGET_DIR="/Users/Aaron/Desktop/Company/Lexis"
MODE="move"       # or "copy"
FORCE=0
DRY=0
ALL=0

for arg in "$@"; do
  case "$arg" in
    --copy) MODE="copy" ;;
    --move) MODE="move" ;;
    --force|-f) FORCE=1 ;;
    --dry-run) DRY=1 ;;
    --all) ALL=1 ;;
    --target=*) TARGET_DIR="${arg#--target=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

REQUIRED_FILES=(
  "LexisApp-Lexis.swift"
  "Services.swift"
  "Models.swift"
  "Theme.swift"
  "TodayView.swift"
  "ArchiveView.swift"
  "QuizView.swift"
  "SettingsView.swift"
)

# Template files we want to remove from the project tree
REDUNDANT_FILES=(
  "LexisApp.swift"
  "Item.swift"
)

mkdir -p "$TARGET_DIR"

find_file() {
  local name="$1"
  # Search from current directory, avoiding common noise folders and the target dir itself
  local path
  path=$(find . -type f -name "$name" \
    -not -path "*/.git/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Pods/*" \
    -not -path "*/.build/*" \
    -not -path "$TARGET_DIR/*" 2>/dev/null | head -n 1 || true)
  echo "$path"
}

log() { echo "[consolidate] $*"; }

MOVED=()
if [[ $ALL -eq 1 ]]; then
  SCRIPT_BASENAME="$(basename "$0")"
  mapfile -t ALL_SOURCES < <(find . -type f \( -name "*.swift" -o -name "*.md" -o -name "*.sh" \) \
    -not -path "*/.git/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Pods/*" \
    -not -path "*/.build/*" \
    -not -path "$TARGET_DIR/*" 2>/dev/null || true)
  for src in "${ALL_SOURCES[@]}"; do
    base="$(basename "$src")"
    # Skip this script itself and the verifier to avoid moving while running
    if [[ "$base" == "$SCRIPT_BASENAME" || "$base" == "verify_lexis_consolidation.sh" ]]; then
      continue
    fi
    dest="$TARGET_DIR/$base"
    if [[ $DRY -eq 1 ]]; then
      log "Would $MODE: $src -> $dest"
    else
      # ensure unique destination if name collision
      dest_unique="$dest"
      if [[ -e "$dest_unique" ]]; then
        name="${base%.*}"
        ext="${base##*.}"
        i=1
        while [[ -e "$TARGET_DIR/${name}_$i.${ext}" ]]; do
          i=$((i+1))
        done
        dest_unique="$TARGET_DIR/${name}_$i.${ext}"
      fi
      if [[ "$MODE" == "copy" ]]; then
        log "Copying: $src -> $dest_unique"
        cp -f "$src" "$dest_unique"
      else
        log "Moving:  $src -> $dest_unique"
        mv -f "$src" "$dest_unique"
      fi
      MOVED+=("$base")
    fi
  done
else
  for f in "${REQUIRED_FILES[@]}"; do
    src=$(find_file "$f")
    if [[ -z "$src" ]]; then
      log "WARN: required file '$f' not found in project tree"
      continue
    fi
    dest="$TARGET_DIR/$f"
    if [[ $DRY -eq 1 ]]; then
      log "Would $MODE: $src -> $dest"
    else
      if [[ "$MODE" == "copy" ]]; then
        log "Copying: $src -> $dest"
        cp -f "$src" "$dest"
      else
        log "Moving:  $src -> $dest"
        mv -f "$src" "$dest"
      fi
      MOVED+=("$f")
    fi
  done
fi

# Delete redundant files from their original locations (not the target dir)
for f in "${REDUNDANT_FILES[@]}"; do
  src=$(find_file "$f")
  [[ -z "$src" ]] && continue
  if [[ $DRY -eq 1 ]]; then
    log "Would delete redundant: $src"
  else
    if [[ $FORCE -eq 1 ]]; then
      log "Deleting redundant: $src"
      rm -f "$src"
    else
      read -r -p "Delete redundant '$src'? [y/N] " ans
      case "$ans" in
        [yY]*) log "Deleting redundant: $src"; rm -f "$src" ;;
        *) log "Skipped: $src" ;;
      esac
    fi
  fi
done

# Verify required files are present in target dir
if [[ -x ./verify_lexis_consolidation.sh ]]; then
  log "Running verification script..."
  ./verify_lexis_consolidation.sh
else
  log "Note: verification script not found or not executable. Skipping."
fi

log "Done."
if [[ "$MODE" == "move" ]]; then
  cat <<EONOTE

Next steps in Xcode:
- Re-add the files from: $TARGET_DIR
- Remove any broken references to old locations
- Product -> Clean Build Folder, then Build & Run
EONOTE
fi

