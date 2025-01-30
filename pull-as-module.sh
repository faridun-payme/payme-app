#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_settings.gradle.kts>"
  exit 1
fi

PROJECT_DIR="$1"

GIT_REPO="https://github.com/faridun-payme/$PROJECT_DIR"
COMMIT_HASH_FILE="$PROJECT_DIR/.last_commit"

LATEST_COMMIT=$(git ls-remote $GIT_REPO refs/heads/master | awk '{print $1}')

if [ -f "$COMMIT_HASH_FILE" ]; then
  LAST_SAVED_COMMIT=$(cat "$COMMIT_HASH_FILE")

  if [ "$LATEST_COMMIT" == "$LAST_SAVED_COMMIT" ]; then
    echo "No changes in $PROJECT_DIR. Skipping update."
    exit 0
  fi
fi

if [ -d "$PROJECT_DIR" ]; then
  echo "Removing old $PROJECT_DIR..."
  rm -rf "$PROJECT_DIR"
fi

echo "Cloning updated $PROJECT_DIR..."
git clone --depth=1 "$GIT_REPO" "$PROJECT_DIR"

rm -rf "$PROJECT_DIR/.git"
rm -rf "$PROJECT_DIR/.gitignore"

echo "$LATEST_COMMIT" > "$COMMIT_HASH_FILE"

echo "$PROJECT_DIR updated to commit: $LATEST_COMMIT"

SETTINGS_FILE="settings.gradle.kts"


if grep -q "// AUTOMATIC UPDATE SECTION" "$SETTINGS_FILE"; then
  sed -i.bak '/\/\/ AUTOMATIC UPDATE SECTION/,$d' "$SETTINGS_FILE"
  rm -f "$SETTINGS_FILE.bak"
fi

echo -e "\n// AUTOMATIC UPDATE SECTION" >> "$SETTINGS_FILE"

MODULES=$(./find_includes.sh "$PROJECT_DIR/settings.gradle.kts")

if [[ -n "$MODULES" ]]; then
  while IFS= read -r MODULE; do
    echo "include(\"$MODULE\")" >> "$SETTINGS_FILE"
  done <<< "$MODULES"
fi

echo "Updated includes in $SETTINGS_FILE"