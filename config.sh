#!/bin/bash

#############################################################
# Git File Rename Configuration
# 
# This file contains all configurable settings for the
# git file rename script.
#############################################################

#############################################################
# Repository Configuration
#############################################################

# Path to file containing list of repository URLs (one per line)
# Comments starting with # and empty lines are ignored
REPO_LIST_FILE="repos.txt"

# Git remote base URL (will be combined with repo name from repos.txt)
# If repos.txt contains full URLs, this is ignored
# If repos.txt contains just repo names, they'll be combined with this base URL
GIT_BASE_URL="https://github.com/your-org"

#############################################################
# Git Authentication
#############################################################

# Git authentication method: "token", "ssh", or "none"
# - "token": Use HTTPS with username and token
# - "ssh": Use SSH keys (ensure ssh-agent is configured)
# - "none": No authentication (for public repos or pre-configured credentials)
GIT_AUTH_METHOD="token"

# Git username for HTTPS authentication (only needed if GIT_AUTH_METHOD="token")
GIT_USERNAME="your-username"

# Git token for HTTPS authentication (only needed if GIT_AUTH_METHOD="token")
# Can also be set via environment variable: export GIT_AUTH_TOKEN="your_token"
# For GitHub: use Personal Access Token with repo permissions
GIT_AUTH_TOKEN="${GIT_AUTH_TOKEN:-}"

#############################################################
# Branch Configuration
#############################################################

# Branch to checkout before making changes
# If empty, uses the current/default branch after cloning
# If set, will checkout this branch before making any file changes
BASE_BRANCH=""

# Branch name to create for changes
# If empty, makes changes on the current branch (BASE_BRANCH or default)
# If set, creates a new branch from BASE_BRANCH for the changes
BRANCH_NAME="update-strings"

# Automatically create branches if they don't exist
AUTO_CREATE_BRANCH=true

#############################################################
# Find/Replace Mappings
#############################################################

# Find/Replace mappings (add as many as needed)
# Format: "old_string|new_string"
# Files containing old_string in their filename will be copied
# and renamed with new_string replacing old_string
declare -a REPLACEMENTS=(
    "oldString1|newString1"
    "oldString2|newString2"
    "TODO: update this|DONE: updated"
)

# Case sensitivity for find/replace operations (true/false)
# If false, will match patterns case-insensitively
CASE_SENSITIVE=true

#############################################################
# Working Directory
#############################################################

# Working directory for cloning repos (will be created if it doesn't exist)
WORK_DIR="./repos_temp"

#############################################################
# Git Configuration
#############################################################

# Commit message (supports multi-line)
COMMIT_MESSAGE="Update string replacements across repository"

# Git author information
# These can be overridden by global git config
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Your Name}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-your.email@example.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

#############################################################
# Logging Configuration
#############################################################

# Log file for tracking completed repos and PR URLs
LOG_FILE="./batch_update_log.txt"

# Enable verbose logging (true/false)
VERBOSE_LOGGING=false

#############################################################
# Script Behavior
#############################################################

# Set to true to enable verbose output
VERBOSE=false

# Set to true to continue on errors (not recommended)
CONTINUE_ON_ERROR=false

# Push changes automatically (can be overridden by command line)
AUTO_PUSH=false
