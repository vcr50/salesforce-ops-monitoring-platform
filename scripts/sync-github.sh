#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This directory is not a git repository."
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No 'origin' remote is configured yet."
  echo "Add a remote first, then run this script again."
  exit 1
fi

branch="$(git branch --show-current)"

if [[ -z "${branch}" ]]; then
  echo "Unable to determine the current branch."
  exit 1
fi

message="${1:-sync: update project files}"

git add -A

if git diff --cached --quiet; then
  echo "No staged changes to commit."
else
  git commit -m "${message}"
fi

git push -u origin "${branch}"
