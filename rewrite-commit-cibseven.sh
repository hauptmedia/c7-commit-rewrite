#!/bin/bash

# Check if a commit SHA was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <commit-sha>"
  exit 1
fi

COMMIT_SHA=$1
BRANCH_NAME="backport-$COMMIT_SHA"

# Define paths to the source (Cibseven) and target (Operaton) repositories
CIBSEVEN_REPO_PATH="$(pwd)/cibseven"
OPERATON_REPO_PATH="$(pwd)/operaton"
PATCH_DIR="$(pwd)/patches"

# Define a function to handle sed compatibility
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -E -i '' "$@"
  else
    sed -E -i "$@"
  fi
}

# Change to the Cibseven repository directory
cd "$CIBSEVEN_REPO_PATH" || exit 1

# Export the specified commit as a patch and capture the generated file name
PATCH_FILE=$(git format-patch -1 "$COMMIT_SHA" -o "$PATCH_DIR" | tail -n 1)

# Replace all instances of 'cibseven' with 'operaton'
sed_inplace 's/Cibseven/Operaton/g' "$PATCH_FILE"
sed_inplace 's/cibseven/operaton/g' "$PATCH_FILE"
sed_inplace 's/CIBSEVEN/OPERATON/g' "$PATCH_FILE"

# fix all wrong replacements
sed_inplace 's/Operaton Services GmbH/Camunda Services GmbH/g' "$PATCH_FILE"
sed_inplace 's/Operaton licenses/Camunda licenses/g' "$PATCH_FILE"

# Extract the original author information from the commit
AUTHOR_NAME=$(git log -1 --format='%an' "$COMMIT_SHA")
AUTHOR_EMAIL=$(git log -1 --format='%ae' "$COMMIT_SHA")

# create a temp file for creating the commit message
TEMP_COMMIT_MESSAGE_FILE=$(mktemp)

# Extract the original commit message
git log -1 --pretty=%B "$COMMIT_SHA" > "$TEMP_COMMIT_MESSAGE_FILE"

# Rewrite issue references in the
# commit message (e.g., "related to #4315" to "related to cibseven/cibseven#4315")
sed_inplace 's/[Rr]elated to[:]* #([0-9]+)/related to cibseven\/cibseven#\1/g' "$TEMP_COMMIT_MESSAGE_FILE"

# Append a backport note to the commit message
  cat <<EOF >>"$TEMP_COMMIT_MESSAGE_FILE"

Backported commit $COMMIT_SHA from the cibseven repository.
Original author: $AUTHOR_NAME <$AUTHOR_EMAIL>
EOF

# Read the modified commit message back into the COMMIT_MESSAGE variable
COMMIT_MESSAGE=$(cat "$TEMP_COMMIT_MESSAGE_FILE")

# Remove the temporary commit message file
rm "$TEMP_COMMIT_MESSAGE_FILE"

# Change to the Operaton repository directory
cd "$OPERATON_REPO_PATH" || exit 1

# Checkout main branch and pull the latest changes
git checkout main
git pull origin main

# Create a new branch from master
git checkout -b "$BRANCH_NAME"

# Attempt to apply the patch
if git apply --verbose "$PATCH_FILE"; then
  # If patch could be automatically applied, create a commit from it
  git add --all
  git commit -am "$COMMIT_MESSAGE"

  # automatically push this commit if we have configured a remote named "fork"
  if git remote | grep -q "^fork$"; then
    echo "Remote 'fork' detected. Pushing branch '$BRANCH_NAME' to 'fork'."
    git push fork "$BRANCH_NAME"
  fi

  # cleanup patch file
  rm "$PATCH_FILE"

else
  cat <<EOF

------------------------------------------------------------------------------------------------------------------------

  Error: Failed to apply the patch for commit $COMMIT_SHA.
  Please apply patch file and resolve conflicts manually.
  A working branch has been automatically created.

------------------------------------------------------------------------------------------------------------------------
  Branch:           $BRANCH_NAME
------------------------------------------------------------------------------------------------------------------------
  Patch file:       $PATCH_FILE
------------------------------------------------------------------------------------------------------------------------
  Commit Message:
----8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<----
$COMMIT_MESSAGE
----8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<--------8<----
EOF
fi
