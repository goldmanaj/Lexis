#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/Users/Aaron/Desktop/Company/Lexis"

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

MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$TARGET_DIR/$f" ]]; then
    MISSING+=("$f")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Missing files in $TARGET_DIR:" >&2
  for f in "${MISSING[@]}"; do echo "  - $f" >&2; done
  exit 1
fi

echo "All required files are present in $TARGET_DIR."
