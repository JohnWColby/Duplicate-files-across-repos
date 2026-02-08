# Git File Rename (Bash Version)

A pure bash script that clones git repositories and creates renamed copies of files based on string substitution patterns. Features robust authentication support, branching, logging, and flexible configuration.

## Quick Start (2 Minutes)

### 1. Configure Authentication (config.sh)

Choose your authentication method:

**Option A: Token (HTTPS) - Recommended**
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

### 2. Set Branches and Base URL (config.sh)
```bash
BASE_BRANCH=""                            # Branch to checkout before changes (empty = use current)
BRANCH_NAME="update-strings"              # New branch to create for changes
GIT_BASE_URL="https://github.com/your-org"  # For short repo names
```

### 3. Define Replacements (config.sh)
```bash
declare -a REPLACEMENTS=(
    "dev|prod"              # config.dev.yaml → config.prod.yaml
    "test|final"            # api.test.js → api.final.js
    "v1|v2"                 # schema-v1.sql → schema-v2.sql
)

CASE_SENSITIVE=true  # or false for case-insensitive
```

### 4. Add Repositories (repos.txt)

**Option A: Full URLs**
```txt
https://github.com/username/repo1.git
git@github.com:username/repo2.git
```

**Option B: Repo names** (uses GIT_BASE_URL)
```txt
repo1
repo2
repo3
```

### 5. Run

```bash
# Test first (dry run)
./git_file_rename.sh -d

# Copy files locally (no push)
./git_file_rename.sh

# Copy and push to git
./git_file_rename.sh -p

# Custom commit message
./git_file_rename.sh -p -m "Add production configs"
```

## Features

- 🔐 **Multiple Authentication Methods**: Token-based (HTTPS), SSH, or no authentication
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

## How It Works

For each repository in `repos.txt`:

1. **Authenticate** using configured method (token/SSH/none)
2. **Clone** the repository (skip if already exists)
3. **Checkout base branch** (if `BASE_BRANCH` is set)
4. **Fetch and pull** base branch (only if no local commits ahead of remote)
5. **Create/checkout working branch** (if `BRANCH_NAME` is set)
6. **Fetch and pull** working branch (only if existing branch with no local commits ahead)
7. **Search** for all files containing each "old" string in their filename
8. **Copy** each matching file to the same location
9. **Rename** the copy by replacing "old" with "new" string
10. **Skip** if the renamed file already exists or would be identical
11. **Commit and push** (if `-p` flag used)
12. **Log** all operations to log file

### Example

**config.sh:**
```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="myusername"
GIT_AUTH_TOKEN="ghp_abc123..."
BASE_BRANCH="main"
BRANCH_NAME="add-prod-configs"

declare -a REPLACEMENTS=(
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

### Smart Branch Handling

The script intelligently handles branch checkout and updates:

**Base Branch Checkout:**
- If already on BASE_BRANCH, stays there
- If BASE_BRANCH exists locally, checks it out
- If BASE_BRANCH only exists remotely, fetches and checks it out
- If BASE_BRANCH doesn't exist, warns and continues on current branch

**Automatic Pull Behavior:**
- After checking out a branch, the script automatically fetches from remote
- If the local branch has **no commits ahead** of remote, it pulls the latest changes
- If the local branch has commits ahead, it **skips the pull** to preserve local work
- This ensures you're working with the latest code while protecting uncommitted work

Example output when pulling is safe:
```
ℹ Checking out base branch: main
✓ Checked out base branch: main
ℹ Pulling latest changes from origin/main...
✓ Successfully pulled latest changes
```

Example output when local commits exist:
```
ℹ Checking out existing branch: my-feature
ℹ Local branch has 2 commit(s) ahead of remote - skipping pull
```

This gives you full control over which branch to start from before creating your working branch!

## Configuration Reference

### Complete config.sh Template

```bash
# Repository list file
REPO_LIST_FILE="repos.txt"

# Git remote base URL (for short repo names)
GIT_BASE_URL="https://github.com/your-org"

# Authentication method: "token", "ssh", or "none"
GIT_AUTH_METHOD="token"
GIT_USERNAME="your-username"
GIT_AUTH_TOKEN="${GIT_AUTH_TOKEN:-}"  # Or: export GIT_AUTH_TOKEN="..."

# Branch to checkout before making changes
# If empty, uses the current/default branch after cloning  
BASE_BRANCH=""

# Branch to create for changes
# If empty, makes changes on BASE_BRANCH (or default)
BRANCH_NAME="update-strings"
AUTO_CREATE_BRANCH=true

# Find/Replace mappings (add as many as needed)
declare -a REPLACEMENTS=(
    "oldString1|newString1"
    "oldString2|newString2"
    "TODO: update this|DONE: updated"
)

# Case sensitivity for find/replace operations (true/false)
CASE_SENSITIVE=true

# Working directory for cloning repos (will be created if it doesn't exist)
WORK_DIR="./repos_temp"

# Commit message (supports multi-line)
COMMIT_MESSAGE="Update string replacements across repository"

# Log file for tracking completed repos and PR URLs
LOG_FILE="./batch_update_log.txt"

# Git author info (optional - uses global config if not set)
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Your Name}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-your.email@example.com}"
```

### Configuration Options Explained

#### Authentication (GIT_AUTH_METHOD)

**Token-Based (HTTPS)** - Best for GitHub/GitLab with personal access tokens
```bash
GIT_AUTH_METHOD="token"
GIT_USERNAME="your-username"
GIT_AUTH_TOKEN="ghp_xxxxx"  # GitHub Personal Access Token
```

To get a GitHub token:
1. GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with `repo` permissions
3. Copy token to config.sh

**SSH** - Best for users with SSH keys configured
```bash
GIT_AUTH_METHOD="ssh"
```

Requirements:
- SSH keys generated: `ssh-keygen`
- Public key added to GitHub/GitLab
- SSH agent running: `ssh-add ~/.ssh/id_rsa`
- Test: `ssh -T git@github.com`

**None** - For public repos or pre-configured credentials
```bash
GIT_AUTH_METHOD="none"
```

#### Repository Format (repos.txt)

**Full URLs:**
```txt
https://github.com/username/repo1.git
git@github.com:username/repo2.git
```

**Short names** (combined with GIT_BASE_URL):
```txt
repo1
repo2
repo3
```

If `GIT_BASE_URL="https://github.com/myorg"`, then `repo1` becomes `https://github.com/myorg/repo1.git`

#### Branch Configuration

```bash
# Checkout a specific branch before making changes
BASE_BRANCH="main"  # or "develop", "staging", etc.

# Create a new branch for the changes
BRANCH_NAME="update-file-copies"

# If BASE_BRANCH is empty, uses current/default branch
BASE_BRANCH=""

# If BRANCH_NAME is empty, makes changes on BASE_BRANCH (or current)
BRANCH_NAME=""

# Auto-create branch if it doesn't exist
AUTO_CREATE_BRANCH=true
```

**Use Cases:**

1. **Work on main branch:**
```bash
BASE_BRANCH="main"
BRANCH_NAME="update-configs"
# Result: Checkouts main → Creates update-configs from main → Makes changes
```

2. **Work on develop branch:**
```bash
BASE_BRANCH="develop"
BRANCH_NAME="feature/new-configs"
# Result: Checkouts develop → Creates feature/new-configs from develop → Makes changes
```

3. **Use current branch:**
```bash
BASE_BRANCH=""
BRANCH_NAME="my-changes"
# Result: Stays on current branch → Creates my-changes → Makes changes
```

4. **Make changes directly on base branch:**
```bash
BASE_BRANCH="staging"
BRANCH_NAME=""
# Result: Checkouts staging → Makes changes directly on staging
```

#### Case Sensitivity

```bash
# Case-sensitive matching (default)
CASE_SENSITIVE=true
# "Dev" ≠ "dev"

# Case-insensitive matching
CASE_SENSITIVE=false
# "Dev" = "dev" = "DEV"
```

#### Commit Messages

```bash
# Single-line message
COMMIT_MESSAGE="Add production config files"

# Multi-line message
COMMIT_MESSAGE="Add production config files

This commit creates production copies of development files
by renaming files based on configured string replacements.

Refs: #123"
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
export GIT_AUTH_TOKEN="ghp_your_token"
./git_file_rename.sh -p
```

## Use Cases

### 1. Environment Configuration Files
```bash
declare -a REPLACEMENTS=(
    "dev|prod"
    "development|production"
    "staging|prod"
)
```
Creates production versions of dev configs.

### 2. Version Migration
```bash
declare -a REPLACEMENTS=(
    "v1|v2"
    "1.0|2.0"
    "old|new"
)
```
Creates next version copies of versioned files.

### 3. Testing to Production
```bash
declare -a REPLACEMENTS=(
    "test|prod"
    "mock|real"
    "sample|live"
)
```
Duplicates test files for production use.

### 4. Multi-Environment Deployment
```bash
declare -a REPLACEMENTS=(
    "local|cloud"
    "onprem|aws"
    "internal|external"
)
```

## Output Example

```
======================================================================
Git File Rename - Starting
======================================================================
✓ Git authentication configured for token-based access
✓ Configuration validated

ℹ Repositories to process: 2
ℹ Replacements: 2
ℹ Case sensitive: true
ℹ Branch: add-prod-configs
ℹ Authentication: token

Replacement mappings:
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
Log file: ./batch_update_log.txt
✓ Operation completed successfully!
```

## Troubleshooting

### Authentication Errors

**Token authentication failing:**
```bash
# Verify token is set
echo $GIT_AUTH_TOKEN

# Set explicitly
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
```

### No Files Found

- Verify pattern exists in filenames (case-sensitive by default)
- Check `CASE_SENSITIVE` setting
- Files in `.git` directories are excluded
- Use dry run to see what's being searched

### Target File Already Exists

The script skips if target file exists. To overwrite:
```bash
cd repos_temp/repo-name
rm *.prod.*  # Delete existing files first
```

### Permission Denied on Push

- Verify you have write access to the repository
- Check branch protection rules
- Ensure token has `repo` permissions (for GitHub)

## Log File

The log file (`LOG_FILE`) tracks all operations:

```
[2024-02-07 10:30:15] === Git File Rename Script Started ===
[2024-02-07 10:30:15] Working directory: ./repos_temp
[2024-02-07 10:30:15] Branch name: update-strings
[2024-02-07 10:30:16] Repository: api-service | Status: CLONED | Details: New clone
[2024-02-07 10:30:18] Repository: api-service | Status: PUSHED | Details: Branch: update-strings
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
declare -a REPLACEMENTS=("dev|prod")
```

Then edit the script to load different configs as needed.

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

**Cron Job:**
```bash
0 2 * * * cd /path/to/git-file-rename && ./git_file_rename.sh -p >> sync.log 2>&1
```

## Best Practices

1. **Always test with dry run first**
   ```bash
   ./git_file_rename.sh -d
   ```

2. **Use specific patterns** to avoid unintended matches

3. **Secure your tokens**
   ```bash
   # Use environment variables
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
- `.gitignore` - Git exclusions
- `batch_update_log.txt` - Operation log (created on first run)

## License

[Specify your license here]

## Changelog

### Version 2.0.0
- Added token-based HTTPS authentication
- Added SSH authentication support
- Added branch creation and management
- Added comprehensive logging with LOG_FILE
- Added case-sensitive/insensitive matching
- Added support for repo names (combined with GIT_BASE_URL)
- Enhanced error handling
- Multi-line commit message support
- Standardized on REPLACEMENTS array name

### Version 1.0.0
- Initial bash version
- Basic repository cloning
- Pattern-based file search and copy
- Pipe-delimited rename mappings
