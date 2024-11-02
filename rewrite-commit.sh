#!/bin/bash

# Check if a commit SHA was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <commit-sha>"
  exit 1
fi

COMMIT_SHA=$1
BRANCH_NAME="backport-$COMMIT_SHA"

# Define paths to the source (Camunda) and target (Operaton) repositories
CAMUNDA_REPO_PATH="$(pwd)/camunda-bpm-platform"
OPERATON_REPO_PATH="$(pwd)/operaton"
PATCH_DIR="$(pwd)/patches"

# Define a function to handle sed compatibility
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Change to the Camunda repository directory
cd "$CAMUNDA_REPO_PATH" || exit 1

# Export the specified commit as a patch and capture the generated file name
PATCH_FILE=$(git format-patch -1 "$COMMIT_SHA" -o "$PATCH_DIR" | tail -n 1)

# Replace all instances of 'camunda' with 'operaton'
sed_inplace 's/Camunda/Operaton/g' "$PATCH_FILE"
sed_inplace 's/camunda/operaton/g' "$PATCH_FILE"

# fix all wrong replacements
sed_inplace 's/operaton\.com/camunda\.com/g' "$PATCH_FILE"
sed_inplace 's|https://github.com/operaton/operaton-bpm-platform|https://github.com/camunda/camunda-bpm-platform|g' "$PATCH_FILE"
sed_inplace 's/Operaton Services GmbH/Camunda Services GmbH/g' "$PATCH_FILE"

# Extract the original author information from the commit
AUTHOR_NAME=$(git log -1 --format='%an' "$COMMIT_SHA")
AUTHOR_EMAIL=$(git log -1 --format='%ae' "$COMMIT_SHA")

# Extract the original commit message
COMMIT_MESSAGE=$(git log -1 --pretty=%B "$COMMIT_SHA")

# Append a backport note to the commit message
COMMIT_MESSAGE+="

This is a backported commit from camunda-bpm-platform. Original author: $AUTHOR_NAME <$AUTHOR_EMAIL>"


# Change to the Operaton repository directory
cd "$OPERATON_REPO_PATH" || exit 1

# Checkout main branch and pull the latest changes
git checkout main
git pull origin main

# Create a new branch at the commit before the specified SHA
git checkout -b "$BRANCH_NAME"

# Apply the modified patch
git apply --verbose "$PATCH_FILE"

# Create a new commit with the original commit message
git add --all
git commit -am "$COMMIT_MESSAGE"
