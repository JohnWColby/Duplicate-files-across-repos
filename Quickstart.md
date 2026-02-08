# Quick Start Guide

## Setup (2 minutes)

### 1. Configure Authentication (config.sh)

Choose your authentication method:

**Option A: Token (HTTPS) - Recommended for most users**
```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="your-username"
GIT_AUTH_TOKEN="ghp_your_github_token"  # Get from GitHub Settings → Developer settings
```

**Option B: SSH**
```bash
GIT_AUTH_METHOD="ssh"
# Ensure: ssh-add ~/.ssh/id_rsa
```

**Option C: None (public repos)**
```bash
GIT_AUTH_METHOD="none"
```

### 2. Set Branch Name (config.sh)
```bash
BRANCH_NAME="update-file-copies"  # Branch to create/use
```

### 3. Define Rename Mappings (config.sh)
```bash
RENAME_PAIRS=(
    "dev|prod"              # config.dev.yaml → config.prod.yaml
    "test|final"            # api.test.js → api.final.js
    "v1|v2"                 # schema-v1.sql → schema-v2.sql
)
```

### 4. Add Repositories (repos.txt)

**Option A: Full URLs**
```txt
https://github.com/username/repo1.git
git@github.com:username/repo2.git
```

**Option B: Repo names** (uses GIT_BASE_URL from config.sh)
```txt
repo1
repo2
repo3
```

## Running

### Test first (dry run):
```bash
./git_file_rename.sh -d
```

### Copy files locally (no push):
```bash
./git_file_rename.sh
```

### Copy and push to git:
```bash
./git_file_rename.sh -p
```

### Custom commit message:
```bash
./git_file_rename.sh -p -m "Add production configs"
```

## How It Works

1. **Clone** each repo (or use existing)
2. **Create/checkout** branch (if BRANCH_NAME set)
3. **Find** files with old string in filename
4. **Copy** file with old→new replacement
5. **Commit & push** (if -p flag used)

**Example:**
- Mapping: `dev|prod`
- File: `config.dev.yaml`
- Creates: `config.prod.yaml` (in same directory)

## Configuration Quick Reference

### config.sh - Essential Settings

```bash
# Authentication (pick one)
GIT_AUTH_METHOD="token"        # or "ssh" or "none"
GIT_USERNAME="username"        # for token method
GIT_AUTH_TOKEN="ghp_xxx"       # for token method

# Repository base (for short names in repos.txt)
GIT_BASE_URL="https://github.com/your-org"

# Branch
BRANCH_NAME="update-files"     # or "" for default branch

# Rename mappings
RENAME_PAIRS=(
    "dev|prod"
    "test|final"
)

# Case sensitivity
CASE_SENSITIVE=true            # or false

# Directories and logs
WORK_DIR="./repos_temp"
LOG_FILE="./batch_update_log.txt"

# Commit message
COMMIT_MESSAGE="Add renamed file copies"
```

### repos.txt - Format

```txt
# Full URLs
https://github.com/user/repo1.git
git@github.com:user/repo2.git

# Or just repo names (combined with GIT_BASE_URL)
repo3
repo4

# Comments and empty lines are ignored
```

## Common Workflows

### Workflow 1: Create Production Configs

**config.sh:**
```bash
GIT_AUTH_METHOD="token"
BRANCH_NAME="add-prod-configs"
RENAME_PAIRS=("dev|prod")
```

**Run:**
```bash
./git_file_rename.sh -d  # Preview
./git_file_rename.sh -p  # Execute and push
```

### Workflow 2: Version Migration

**config.sh:**
```bash
BRANCH_NAME="v2-migration"
RENAME_PAIRS=(
    "v1|v2"
    "1.0|2.0"
)
```

**Run:**
```bash
./git_file_rename.sh -p -m "Migrate to version 2"
```

### Workflow 3: Multi-Environment

**config.sh:**
```bash
BRANCH_NAME="staging-configs"
RENAME_PAIRS=(
    "dev|staging"
    "local|cloud"
)
CASE_SENSITIVE=false  # Match Dev, DEV, dev
```

## Output Example

```
======================================================================
Git File Rename - Starting
======================================================================
✓ Git authentication configured for token-based access
✓ Configuration validated

ℹ Repositories to process: 2
ℹ Rename mappings: 2
ℹ Branch: add-prod-configs

Rename map:
  'dev' → 'prod'
  'test' → 'final'

======================================================================
Processing repository: backend
======================================================================
✓ Successfully cloned
ℹ Creating new branch: add-prod-configs

ℹ Searching for files containing 'dev' in filename...
  Found 2 file(s)
  Processing: config.dev.yaml
✓ Created: config.prod.yaml
  Processing: database.dev.json
✓ Created: database.prod.json

Files copied in backend: 2

======================================================================
Git Push Operations
======================================================================
✓ Successfully pushed changes

======================================================================
Summary
======================================================================
Total files copied: 2
Successful repositories: 1/1
✓ Operation completed successfully!
```

## Command Reference

```bash
# Show help
./git_file_rename.sh -h

# Dry run (preview)
./git_file_rename.sh -d

# Execute (copy files, no push)
./git_file_rename.sh

# Execute and push
./git_file_rename.sh -p

# Custom commit message
./git_file_rename.sh -p -m "Your message"

# Use environment variable for token
export GIT_AUTH_TOKEN="ghp_xxx"
./git_file_rename.sh -p
```

## What Gets Created

**Before:**
```
repo/
├── config.dev.yaml
├── api.test.js
└── utils.js
```

**After** (with `dev|prod` and `test|final`):
```
repo/ (on branch: update-files)
├── config.dev.yaml
├── config.prod.yaml    ← NEW (copy)
├── api.test.js
├── api.final.js        ← NEW (copy)
└── utils.js
```

## Troubleshooting

### Token Authentication

```bash
# Get GitHub token
# 1. GitHub → Settings → Developer settings → Personal access tokens
# 2. Generate new token (classic)
# 3. Select 'repo' scope
# 4. Copy token to config.sh

# Verify it's set
echo $GIT_AUTH_TOKEN

# Or use environment
export GIT_AUTH_TOKEN="ghp_your_token"
```

### SSH Authentication

```bash
# Check SSH keys
ssh-add -l

# Add key if needed
ssh-add ~/.ssh/id_rsa

# Test GitHub connection
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

### No Files Found

- Check pattern exists in filenames
- Verify CASE_SENSITIVE setting
- Use dry run to debug: `./git_file_rename.sh -d`

### Repository Not Cloning

```bash
# For full URLs - check URL is correct
https://github.com/username/repo.git  # ✓
https://github.com/username/repo      # ✗ (missing .git)

# For repo names - check GIT_BASE_URL
GIT_BASE_URL="https://github.com/your-org"
```

### Permission Errors

- Verify token has `repo` permissions
- Check you have write access to repository
- Review branch protection rules

## Tips

✅ **Always dry run first:** `./git_file_rename.sh -d`  
✅ **Use specific patterns** to avoid unwanted matches  
✅ **Check the log file:** `cat ./batch_update_log.txt`  
✅ **Secure your token:** Use environment variables  
✅ **Test on one repo first** before processing many  

## Next Steps

1. **Test locally**
   ```bash
   ./git_file_rename.sh -d
   ```

2. **Execute and review**
   ```bash
   ./git_file_rename.sh
   # Review changes in repos_temp/
   ```

3. **Push when ready**
   ```bash
   ./git_file_rename.sh -p
   ```

4. **Check the log**
   ```bash
   cat ./batch_update_log.txt
   ```

## Full config.sh Template

```bash
# Authentication
GIT_AUTH_METHOD="token"
GIT_USERNAME="your-username"
export GIT_AUTH_TOKEN="ghp_your_token"  # Or set via: export GIT_AUTH_TOKEN=...

# Repository
GIT_BASE_URL="https://github.com/your-org"
REPO_LIST_FILE="repos.txt"

# Branch
BRANCH_NAME="update-files"
AUTO_CREATE_BRANCH=true

# Rename mappings
RENAME_PAIRS=(
    "dev|prod"
    "staging|production"
    "test|final"
    "v1|v2"
)

# Settings
CASE_SENSITIVE=true
WORK_DIR="./repos_temp"
LOG_FILE="./batch_update_log.txt"
COMMIT_MESSAGE="Add renamed file copies"
```

## Resources

- **Full documentation:** See README.md
- **Log file:** ./batch_update_log.txt
- **GitHub tokens:** Settings → Developer settings → Personal access tokens
- **SSH setup:** `ssh-keygen` then add key to GitHub
