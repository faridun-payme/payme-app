#!/bin/bash

BUILD_LOGIC_DIR="build-logic"
GIT_REPO="https://github.com/faridun-payme/payme-build-logic"
COMMIT_HASH_FILE="$BUILD_LOGIC_DIR/.last_commit"

# Получаем последний коммит из удалённого репозитория
LATEST_COMMIT=$(git ls-remote $GIT_REPO refs/heads/master | awk '{print $1}')

# Проверяем, есть ли уже сохранённый коммит
if [ -f "$COMMIT_HASH_FILE" ]; then
  LAST_SAVED_COMMIT=$(cat "$COMMIT_HASH_FILE")

  if [ "$LATEST_COMMIT" == "$LAST_SAVED_COMMIT" ]; then
    echo "No changes in build-logic. Skipping update."
    exit 0
  fi
fi

# Если коммит изменился, удаляем старую папку
if [ -d "$BUILD_LOGIC_DIR" ]; then
  echo "Removing old build-logic..."
  rm -rf "$BUILD_LOGIC_DIR"
fi

# Клонируем новый build-logic
echo "Cloning updated build-logic..."
git clone --depth=1 "$GIT_REPO" "$BUILD_LOGIC_DIR"

# Удаляем .git, чтобы это не было отдельным репозиторием
rm -rf "$BUILD_LOGIC_DIR/.git"
rm -rf "$BUILD_LOGIC_DIR/.gitignore"

# Сохраняем новый коммитный хеш
echo "$LATEST_COMMIT" > "$COMMIT_HASH_FILE"

echo "Build-logic updated to commit: $LATEST_COMMIT"
