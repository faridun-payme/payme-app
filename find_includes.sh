#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_settings.gradle.kts>"
  exit 1
fi

SETTINGS_FILE="$1"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Error: File $SETTINGS_FILE not found!"
  exit 1
fi

grep -E '^\s*include\(([^)]*)\)' "$SETTINGS_FILE" | \
    sed -E 's/^\s*include\(([^)]*)\)/\1/' | \
    tr -d '"' | \
    tr ',' '\n' | \
    sed '/:app/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'