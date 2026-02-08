# Git File Rename (Bash Version)

A pure bash script that clones git repositories and creates renamed copies of files based on string substitution patterns. Features robust authentication support, branching, logging, and flexible configuration.

## Features

- 🔄 **Automatic Repository Cloning**: Clones repositories if they don't exist locally (silently continues if already cloned)
- 🔐 **Multiple Authentication Methods**: Supports token-based (HTTPS), SSH, or no authentication
- 🌿 **Branch Management**: Create and work on specific branches
- 🔍 **Pattern-Based File Search**: Finds files containing specific strings in their filenames
- 📝 **Smart File Copying**: Creates renamed copies in the same location as originals
- 🎯 **Multiple Repository Support**: Process multiple repositories in a single run
- 🗺️ **Pipe-Delimited Mappings**: Define string substitution rules as `old|new` pairs
- 📊 **Case Sensitivity Control**: Choose case-sensitive or case-insensitive matching
- 🧪 **Dry Run Mode**: Preview what would be renamed without making changes
- 🚀 **Optional Git Push**: Commit and push renamed files automatically
- 📋 **Comprehensive Logging**: Track all operations in a log file
- 💯 **Pure Bash**: No Python dependencies required

## Quick Start

1. **Edit `config.sh`** with your settings:
```bash
# Authentication
GIT_AUTH_METHOD="token"  # or "ssh" or "none"
GIT_USERNAME="your-username"
GIT_AUTH_TOKEN="your_token_here"

# Branch to create/use
BRANCH_NAME="update-file-copies"

# Rename mappings
RENAME_PAIRS=(
    "dev|prod"
    "test|final"
)
```

2. **Edit `repos.txt`** with your repositories:
```txt
https://github.com/username/repo1.git
repo2
repo3
```

3. **Run**:
```bash
./git_file_rename.sh -d  # Dry run
./git_file_rename.sh     # Execute
./git_file_rename.sh -p  # Execute and push
```

## Configuration Guide

### Authentication Methods

#### Token-Based Authentication (HTTPS)

Best for: GitHub, GitLab, Bitbucket with personal access tokens

```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="your-username"
GIT_AUTH_TOKEN="ghp_your_github_token"  # or set via: export GIT_AUTH_TOKEN="..."
```

**GitHub Personal Access Token:**
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with `repo` permissions
3. Copy token to `GIT_AUTH_TOKEN`

#### SSH Authentication

Best for: Users with SSH keys configured

```bash
GIT_AUTH_METHOD="ssh"
```

Requirements:
- SSH keys generated (`ssh-keygen`)
- Public key added to GitHub/GitLab
- SSH agent running with key loaded (`ssh-add ~/.ssh/id_rsa`)

Test with: `ssh -T git@github.com`

#### No Authentication

Best for: Public repositories or pre-configured credentials

```bash
GIT_AUTH_METHOD="none"
```

Uses system's default git configuration.

### Repository List (repos.txt)

Supports two formats:

**1. Full URLs:**
```txt
https://github.com/username/repo1.git
git@github.com:username/repo2.git
```

**2. Repository names only:**
```txt
repo1
repo2
repo3
```

When using names only, they're combined with `GIT_BASE_URL`:
```bash
GIT_BASE_URL="https://github.com/your-org"
# repo1 becomes: https://github.com/your-org/repo1.git
```

### Rename Mappings

Define in `config.sh`:

```bash
RENAME_PAIRS=(
    "dev|prod"              # config.dev.yaml → config.prod.yaml
    "staging|production"    # api.staging.js → api.production.js
    "test|final"            # data.test.json → data.final.json
    "v1|v2"                 # schema-v1.sql → schema-v2.sql
)
```

Alternative name (same functionality):
```bash
REPLACEMENTS=(
    "dev|prod"
    "test|final"
)
```

### Branch Configuration

```bash
# Create/use a specific branch
BRANCH_NAME="update-file-copies"

# Work on default branch (leave empty)
BRANCH_NAME=""

# Auto-create branch if it doesn't exist
AUTO_CREATE_BRANCH=true
```

### Case Sensitivity

```bash
# Case-sensitive matching (default)
CASE_SENSITIVE=true
# "Dev" ≠ "dev"

# Case-insensitive matching
CASE_SENSITIVE=false
# "Dev" = "dev" = "DEV"
```

### Working Directory

```bash
# Where repositories are cloned
WORK_DIR="./repos_temp"

# Will be created if it doesn't exist
# Use absolute path for consistency
```

### Logging

```bash
# Log file location
LOG_FILE="./batch_update_log.txt"

# Enable detailed logging
VERBOSE_LOGGING=true

# Log contains:
# - Timestamp of operations
# - Repository status (cloned, exists, failed)
# - Files copied
# - Push results
```

### Commit Message

```bash
# Multi-line commit message
COMMIT_MESSAGE="Add renamed file copies

This commit creates production copies of development files
by renaming files based on configured string replacements."

# Or simple message
COMMIT_MESSAGE="Add production config files"
```

## Usage

### Command Line Options

```bash
./git_file_rename.sh [OPTIONS]

Options:
  -d, --dry-run       Preview changes without copying files
  -p, --push          Commit and push changes after copying
  -m, --message MSG   Commit message (used with --push)
  -h, --help          Show help message
```

### Common Workflows

**1. Preview changes (dry run):**
```bash
./git_file_rename.sh -d
```

**2. Copy files locally (no commit):**
```bash
./git_file_rename.sh
```

**3. Copy and commit (no push):**
```bash
# Set AUTO_PUSH=false in config.sh
./git_file_rename.sh
```

**4. Copy, commit, and push:**
```bash
./git_file_rename.sh -p
```

**5. Custom commit message:**
```bash
./git_file_rename.sh -p -m "Create production configuration files"
```

**6. Using environment variables:**
```bash
# Set token via environment
export GIT_AUTH_TOKEN="ghp_your_token"
./git_file_rename.sh -p
```

## How It Works

For each repository in `repos.txt`:

1. **Authenticate** using configured method (token/SSH/none)
2. **Clone** the repository (skip if already exists)
3. **Create/checkout branch** (if `BRANCH_NAME` is set)
4. **Search** for all files containing each "old" string in their filename
5. **Copy** each matching file to the same location
6. **Rename** the copy by replacing "old" with "new" string
7. **Skip** if the renamed file already exists or would be identical
8. **Commit and push** (if `-p` flag used)
9. **Log** all operations to log file

### Example

**config.sh:**
```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="myusername"
GIT_AUTH_TOKEN="ghp_abc123..."
BRANCH_NAME="add-prod-configs"

RENAME_PAIRS=(
    "dev|prod"
    "test|final"
)

CASE_SENSITIVE=true
```

**repos.txt:**
```txt
git@github.com:company/backend.git
```

**Files in repository:**
```
backend/
├── config.dev.yaml
├── database.dev.json
├── api.test.js
└── utils.js
```

**Command:**
```bash
./git_file_rename.sh -p
```

**Result:**
```
backend/ (on branch: add-prod-configs)
├── config.dev.yaml
├── config.prod.yaml        ← NEW (copy of config.dev.yaml)
├── database.dev.json
├── database.prod.json      ← NEW (copy of database.dev.json)
├── api.test.js
├── api.final.js            ← NEW (copy of api.test.js)
└── utils.js

Commits created and pushed to: add-prod-configs
```

## Detailed Example

**Setup (config.sh):**
```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="mycompany"
GIT_AUTH_TOKEN="ghp_xxxxxxxxxxxxx"
GIT_BASE_URL="https://github.com/mycompany"
BRANCH_NAME="prod-configs"
WORK_DIR="./repos_temp"
LOG_FILE="./operations.log"

RENAME_PAIRS=(
    "dev|prod"
    "staging|production"
)

CASE_SENSITIVE=true
COMMIT_MESSAGE="Add production configuration files"
```

**repos.txt:**
```txt
api-service
web-app
mobile-backend
```

**Run:**
```bash
./git_file_rename.sh -d  # Preview
./git_file_rename.sh -p  # Execute and push
```

**Output:**
```
======================================================================
Git File Rename - Starting
======================================================================
Config file: ./config.sh
Repository list: repos.txt
Working directory: ./repos_temp
Log file: ./operations.log

✓ Git authentication configured for token-based access
✓ Configuration validated

ℹ Repositories to process: 3
ℹ Rename mappings: 2
ℹ Case sensitive: true
ℹ Branch: prod-configs
ℹ Authentication: token

Rename map:
  'dev' → 'prod'
  'staging' → 'production'

======================================================================
Processing repository: api-service
======================================================================
ℹ Cloning repository: api-service
✓ Successfully cloned to: ./repos_temp/api-service
ℹ Creating new branch: prod-configs

ℹ Searching for files containing 'dev' in filename...
  Found 3 file(s)
  Processing: config/database.dev.yaml
✓ Created: database.prod.yaml
  Processing: config/redis.dev.yaml
✓ Created: redis.prod.yaml
  Processing: config/cache.dev.json
✓ Created: cache.prod.json

Files copied in api-service: 3

======================================================================
Git Push Operations
======================================================================

ℹ Git operations in: api-service
  Adding changes...
  Committing changes...
  Pushing to branch: prod-configs
✓ Successfully pushed changes

======================================================================
Summary
======================================================================
Total files copied: 8
Successful repositories: 3/3
Log file: ./operations.log

✓ Operation completed successfully!
```

## Use Cases

### 1. Environment Configuration Files
```bash
RENAME_PAIRS=(
    "dev|prod"
    "development|production"
    "staging|prod"
)
```
Creates production versions of dev configs.

### 2. Version Migration
```bash
RENAME_PAIRS=(
    "v1|v2"
    "1.0|2.0"
    "old|new"
)
```
Creates next version copies of versioned files.

### 3. Testing to Production
```bash
RENAME_PAIRS=(
    "test|prod"
    "mock|real"
    "sample|live"
)
```
Duplicates test files for production use.

### 4. Multi-Environment Deployment
```bash
RENAME_PAIRS=(
    "local|cloud"
    "onprem|aws"
    "internal|external"
)
```

## Troubleshooting

### Authentication Errors

**Token authentication failing:**
```bash
# Verify token is set
echo $GIT_AUTH_TOKEN

# Or set it explicitly
export GIT_AUTH_TOKEN="your_token"

# Check username matches repository owner
GIT_USERNAME="correct-username"
```

**SSH authentication failing:**
```bash
# Check SSH agent
ssh-add -l

# Add key if needed
ssh-add ~/.ssh/id_rsa

# Test connection
ssh -T git@github.com
```

### Repository Not Found

```bash
# For full URLs - verify URL is correct
https://github.com/username/repo.git

# For repo names - verify GIT_BASE_URL is correct
GIT_BASE_URL="https://github.com/your-org"
```

### Branch Issues

```bash
# Branch doesn't exist and AUTO_CREATE_BRANCH=false
AUTO_CREATE_BRANCH=true  # Enable auto-creation

# Or create branch manually first
git checkout -b your-branch-name
```

### No Files Found

- Verify pattern exists in filenames (case-sensitive by default)
- Check `CASE_SENSITIVE` setting
- Files in `.git` directories are excluded
- Use dry run to see what's being searched

### Target File Already Exists

The script skips if target file exists. To overwrite:
```bash
# Delete existing files first
cd repos_temp/repo-name
rm *.prod.*  # or specific files
```

### Permission Denied on Push

- Verify you have write access to the repository
- Check branch protection rules
- Ensure token has `repo` permissions (for GitHub)

## Log File

The log file tracks:

```
[2024-02-07 10:30:15] === Git File Rename Script Started ===
[2024-02-07 10:30:15] Working directory: ./repos_temp
[2024-02-07 10:30:15] Branch name: prod-configs
[2024-02-07 10:30:16] Repository: api-service | Status: CLONED | Details: New clone
[2024-02-07 10:30:18] Repository: api-service | Status: PUSHED | Details: Branch: prod-configs
[2024-02-07 10:30:20] === Script Completed ===
[2024-02-07 10:30:20] Total files copied: 3
[2024-02-07 10:30:20] Successful repos: 1/1
```

View log:
```bash
cat ./batch_update_log.txt
tail -f ./batch_update_log.txt  # Live monitoring
```

## Advanced Usage

### Multiple Configuration Files

Create environment-specific configs:

**config-prod.sh:**
```bash
source config.sh  # Load defaults
BRANCH_NAME="prod-configs"
RENAME_PAIRS=("dev|prod")
```

**config-staging.sh:**
```bash
source config.sh
BRANCH_NAME="staging-configs"
RENAME_PAIRS=("dev|staging")
```

### Scripted Automation

```bash
#!/bin/bash
# deploy-configs.sh

# Deploy to staging
export GIT_AUTH_TOKEN=$STAGING_TOKEN
BRANCH_NAME="staging" ./git_file_rename.sh -p

# Deploy to production
export GIT_AUTH_TOKEN=$PROD_TOKEN
BRANCH_NAME="production" ./git_file_rename.sh -p
```

### Integration with CI/CD

**GitHub Actions:**
```yaml
name: Update Configs
on:
  workflow_dispatch:
    
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run file rename
        env:
          GIT_AUTH_TOKEN: ${{ secrets.GH_TOKEN }}
        run: |
          cd git-file-rename
          ./git_file_rename.sh -p
```

**Jenkins Pipeline:**
```groovy
pipeline {
    agent any
    stages {
        stage('Update Files') {
            steps {
                withCredentials([string(credentialsId: 'git-token', variable: 'GIT_AUTH_TOKEN')]) {
                    sh './git_file_rename.sh -p'
                }
            }
        }
    }
}
```

## Best Practices

1. **Always test with dry run first**
   ```bash
   ./git_file_rename.sh -d
   ```

2. **Use specific patterns** to avoid unintended matches

3. **Secure your tokens**
   ```bash
   # Use environment variables, not hardcoded
   export GIT_AUTH_TOKEN="your_token"
   
   # Or use secret management
   GIT_AUTH_TOKEN=$(vault read -field=token secret/git)
   ```

4. **Review before pushing**
   ```bash
   ./git_file_rename.sh       # Review local changes
   ./git_file_rename.sh -p    # Push if satisfied
   ```

5. **Use branch protection** for important branches

6. **Monitor the log file** for issues

7. **Keep backups** before bulk operations

## Requirements

- Bash 4.0 or higher
- Git 2.0 or higher
- Standard Unix tools (find, grep, basename, sed)

## Files

- `git_file_rename.sh` - Main bash script
- `config.sh` - Configuration file
- `repos.txt` - Repository list
- `README.md` - This file
- `QUICKSTART.md` - Quick reference guide
- `batch_update_log.txt` - Operation log (created on first run)

## License

[Specify your license here]

## Changelog

### Version 2.0.0
- Added token-based HTTPS authentication
- Added SSH authentication support
- Added branch creation and management
- Added comprehensive logging
- Added case-sensitive/insensitive matching
- Added support for repo names (combined with base URL)
- Enhanced error handling
- Multi-line commit message support

### Version 1.0.0
- Initial bash version
- Basic repository cloning
- Pattern-based file search and copy
- Pipe-delimited rename mappings
