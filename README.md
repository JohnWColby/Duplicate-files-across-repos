# Git File Rename (Bash Version)

A pure bash script that clones git repositories and creates renamed copies of files based on string substitution patterns. Features robust authentication support, branching, logging, and flexible configuration.

## Quickstart (5 Minutes)

### Prerequisites
- Bash 4.0+ (for bash version) OR Python 3.6+ (for Python version)
- Git 2.0+
- SSH keys configured (for SSH auth) OR GitHub Personal Access Token (for token auth)

### Setup

**1. Get your authentication ready:**

For **Token authentication** (recommended):
```bash
# Get token from: GitHub Settings → Developer settings → Personal access tokens
# Generate new token with 'repo' permissions
export GIT_AUTH_TOKEN="ghp_your_token_here"
```

For **SSH authentication**:
```bash
# Ensure your SSH key is added and loaded
ssh-add ~/.ssh/id_rsa
ssh -T git@github.com  # Test connection
```

**2. Configure the script:**

Edit `config.sh`:
```bash
# Authentication
GIT_AUTH_METHOD="token"  # or "ssh" or "none"
GIT_USERNAME="your-github-username"
GIT_AUTH_TOKEN="${GIT_AUTH_TOKEN:-}"  # Uses environment variable

# Repository base URL
GIT_BASE_URL="https://github.com/your-org"

# Branches
BASE_BRANCH="main"           # Branch to start from
BRANCH_NAME="add-prod-files" # Branch to create for changes

# What to copy/rename
declare -a REPLACEMENTS=(
    "dev|prod"     # config.dev.yaml → config.prod.yaml
    "test|final"   # api.test.js → api.final.js
)
```

**3. Add your repositories:**

Edit `repos.txt`:
```txt
repo1
repo2
backend-service
```

Or use full URLs:
```txt
https://github.com/user/repo1.git
git@github.com:user/repo2.git
```

**4. Run the script:**

**Bash version:**
```bash
# Test first (dry run)
./git_file_rename.sh -d

# Copy and push
./git_file_rename.sh -p
```

**Python version:**
```bash
# Test first (dry run)
python3 git_file_rename.py -d

# Copy and push
python3 git_file_rename.py -p
```

**Parallel execution (for many repos):**
```bash
# Run with 4 parallel processes (4x faster!)
./parallel_run.sh -j 4

# See "Parallel Execution Guide" section below for details
```

### What It Does

For each repository:
1. Clones the repo (or uses existing)
2. Checks out `BASE_BRANCH` (pulls latest if no local commits)
3. Creates `BRANCH_NAME` branch
4. Finds all files/directories containing "dev" or "test" in their names
5. Creates copies renamed to "prod" or "final"
6. Replaces "dev"→"prod" and "test"→"final" **inside** the copied files
7. Commits and pushes to the new branch

### Common Issues

**"Authentication failed"**
```bash
# For token auth, verify token is set:
echo $GIT_AUTH_TOKEN

# For SSH, verify key is loaded:
ssh-add -l
```

**"Command not found"**
```bash
# Make scripts executable:
chmod +x git_file_rename.sh git_file_rename.py
```

**"No files found"**
- Check pattern matching in `REPLACEMENTS` array
- Verify files exist with those patterns in their names
- Check `CASE_SENSITIVE` setting (default: true)

### Quick Reference

| Task | Bash | Python | Parallel |
|------|------|--------|----------|
| Dry run | `./git_file_rename.sh -d` | `python3 git_file_rename.py -d` | `./parallel_run.sh -j 4 -a "-d"` |
| Copy only | `./git_file_rename.sh` | `python3 git_file_rename.py` | `./parallel_run.sh -j 4 -a ""` |
| Copy & push | `./git_file_rename.sh -p` | `python3 git_file_rename.py -p` | `./parallel_run.sh -j 4` |
| Fix existing | `./git_file_rename.sh -f -p` | `python3 git_file_rename.py -f -p` | `./parallel_run.sh -j 4 -a "-f -p"` |
| Custom message | `./git_file_rename.sh -p -m "msg"` | `python3 git_file_rename.py -p -m "msg"` | `./parallel_run.sh -a "-p -m 'msg'"` |

---

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

# Fix mode: update content in existing files only (no copying)
./git_file_rename.sh --fix-content
./git_file_rename.sh --fix-content -p  # Fix and push
```

## Features

- 🔐 **Multiple Authentication Methods**: Token-based (HTTPS), SSH, or no authentication
- 🌿 **Branch Management**: Create and work on specific branches
- 🔍 **Pattern-Based Search**: Finds files and directories containing specific strings in their names
- 📝 **Smart Copying**: Creates renamed copies of files and directories in the same location
- 🔄 **Content Replacement**: Automatically replaces old strings with new strings inside copied files
- 📁 **Directory Support**: Recursively copies entire directories with all contents
- 🎯 **Multiple Repository Support**: Process multiple repositories in a single run
- 🗺️ **Pipe-Delimited Mappings**: Define string substitution rules as `old|new` pairs
- 📊 **Case Sensitivity Control**: Choose case-sensitive or case-insensitive matching
- 🧪 **Dry Run Mode**: Preview what would be renamed without making changes
- 🚀 **Optional Git Push**: Commit and push renamed files automatically
- 📋 **Comprehensive Logging**: Track all operations in a log file
- 💯 **Pure Bash**: No Python dependencies required

## How It Works

The script processes each repository **sequentially and completely** before moving to the next one.

For each repository in `repos.txt`:

1. **Authenticate** using configured method (token/SSH/none)
2. **Clone** the repository (skip if already exists)
3. **Checkout base branch** (if `BASE_BRANCH` is set)
4. **Fetch and pull** base branch (only if no local commits ahead of remote)
5. **Create/checkout working branch** (if `BRANCH_NAME` is set)
6. **Fetch and pull** working branch (only if existing branch with no local commits ahead)
7. **Search** for all files and directories containing each "old" string in their name
8. **Copy** each matching file or directory (with all contents) to the same location
9. **Rename** the copy by replacing "old" with "new" string in the name
10. **Replace content** within all copied files, changing "old" to "new" strings
11. **Skip** if the renamed item already exists or would be identical
12. **Commit and push** changes immediately (if `-p` flag used and changes were made)
13. **Move to next repository** and repeat

Each repository is processed completely (including git push) before the next repository begins. This ensures that if an error occurs, previous repositories have already been committed and pushed.

### Benefits of Sequential Processing

- **Fault Isolation**: If repo #5 fails, repos #1-4 are already committed and pushed
- **Progress Visibility**: See each repository complete before the next one starts
- **Easier Debugging**: Identify exactly which repository had issues
- **Partial Success**: Some repositories succeed even if others fail
- **Clean Workflow**: Each repository goes through the complete cycle independently

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
├── scripts.dev/
│   ├── deploy.sh
│   └── backup.sh
└── utils.js
```

**Content of `config.dev.yaml`:**
```yaml
cluster: backend-dev
environment: dev
api_url: https://dev.api.example.com
```

**Content of `scripts.dev/deploy.sh`:**
```bash
#!/bin/bash
CLUSTER="dev-cluster"
ENV="dev"
```

**Command:**
```bash
./git_file_rename.sh -p
```

**Result:**
```
backend/ (on branch: add-prod-configs)
├── config.dev.yaml
├── config.prod.yaml        ← NEW (copy with updated content)
├── database.dev.json
├── database.prod.json      ← NEW (copy with updated content)
├── api.test.js
├── api.final.js            ← NEW (copy with updated content)
├── scripts.dev/
│   ├── deploy.sh
│   └── backup.sh
├── scripts.prod/           ← NEW (copy with updated content in all files)
│   ├── deploy.sh
│   └── backup.sh
└── utils.js

Commits created and pushed to: add-prod-configs
```

**Content of `config.prod.yaml` (after copy):**
```yaml
cluster: backend-prod      ← Changed from 'backend-dev'
environment: prod          ← Changed from 'dev'
api_url: https://prod.api.example.com  ← Changed from 'dev.api'
```

**Content of `scripts.prod/deploy.sh` (after copy):**
```bash
#!/bin/bash
CLUSTER="prod-cluster"     ← Changed from 'dev-cluster'
ENV="prod"                 ← Changed from 'dev'
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

## Content Replacement

The script doesn't just rename files and directories—it also **replaces content** within the copied files.

### How It Works

After copying a file or directory, the script automatically:
1. **Searches** through all text files in the copy
2. **Replaces** all occurrences of the old string with the new string
3. **Preserves** binary files (no changes to images, executables, etc.)
4. **Respects** case sensitivity settings

### Example

**Original file: `config.dev.yaml`**
```yaml
cluster_name: my-app-dev
environment: dev
api_url: https://dev.example.com
database: postgres-dev
```

**After copying to `config.prod.yaml` with mapping `dev|prod`:**
```yaml
cluster_name: my-app-prod      ← Changed
environment: prod              ← Changed
api_url: https://prod.example.com  ← Changed
database: postgres-prod        ← Changed
```

### Directory Content Replacement

When copying directories, the script replaces content in **all text files** within the directory:

**Original: `scripts.dev/deploy.sh`**
```bash
#!/bin/bash
CLUSTER="dev-cluster"
NAMESPACE="app-dev"
```

**After copying to `scripts.prod/deploy.sh`:**
```bash
#!/bin/bash
CLUSTER="prod-cluster"         ← Changed
NAMESPACE="app-prod"          ← Changed
```

### Output Example

```
ℹ Searching for files/directories containing 'dev' in name...
  Found 2 item(s)
  Processing file: config.dev.yaml
✓ Created file: config.prod.yaml
      → Replaced content in: config.prod.yaml
  Processing directory: scripts.dev/
✓ Created directory: scripts.prod/
      → Replaced content in: deploy.sh
      → Replaced content in: backup.sh
      → Replaced content in: config.json
```

### Safety Features

- **Binary files preserved**: Images, executables, archives are not modified
- **Smart detection**: Uses `file` command to identify text vs binary
- **Case sensitivity**: Respects the `CASE_SENSITIVE` setting for content replacement
- **Dry run preview**: Shows what would be replaced without making changes

### Use Cases

This is particularly useful for:
- **Environment configs** with cluster names, URLs, database names
- **Deployment scripts** with environment-specific variables
- **Infrastructure code** with resource names and identifiers
- **Configuration files** with service endpoints and credentials

## Fix Mode

**Fix Mode** is designed to update content in files that were already copied/renamed before the content replacement feature was added to the script.

### What is Fix Mode?

Instead of creating new copies, Fix Mode:
1. **Searches** for files/directories containing the **NEW** pattern (mapping values like "prod")
2. **Replaces** any occurrences of the **OLD** pattern (mapping keys like "dev") within those files
3. **Skips** copying or renaming - only updates content

### When to Use Fix Mode

- You ran the script before content replacement was added
- You manually created prod/staging files that still contain dev/test references
- You need to update existing files without creating new copies
- You want to fix files that were incorrectly copied

### How to Use Fix Mode

**Via Command Line:**
```bash
# Dry run to see what would be fixed
./git_file_rename.sh --fix-content -d

# Fix content in existing files
./git_file_rename.sh --fix-content

# Fix and push changes
./git_file_rename.sh --fix-content -p -m "Fix content references"
```

**Via Configuration:**
```bash
# In config.sh
FIX_MODE=true

# Then run normally
./git_file_rename.sh
```

### Example Scenario

**Problem:** You have prod files that still reference "dev" internally

**Files:**
```
repo/
├── config.dev.yaml        (cluster: my-app-dev)
└── config.prod.yaml       (cluster: my-app-dev) ← WRONG!
```

**Mapping:**
```bash
REPLACEMENTS=("dev|prod")
```

**Fix Mode Behavior:**
```bash
./git_file_rename.sh --fix-content
```

1. Searches for files with "prod" in name → Finds `config.prod.yaml`
2. Checks if file contains "dev" → Yes it does
3. Replaces "dev" → "prod" in file content

**Result:**
```
repo/
├── config.dev.yaml        (cluster: my-app-dev)
└── config.prod.yaml       (cluster: my-app-prod) ← FIXED!
```

### Fix Mode Output

```
======================================================================
Git File Rename - Starting
======================================================================
MODE: Fix existing files (content replacement only)

======================================================================
Processing repository (FIX MODE): backend
======================================================================

ℹ Searching for files/directories containing 'prod' in name (to fix content)...
  Found 3 item(s) to check for content replacement
  Checking file: config.prod.yaml
      → Replaced content in: config.prod.yaml
  Checking file: database.prod.json
      → Replaced content in: database.prod.json
  Checking directory: scripts.prod/
✓ Fixed content in 3 file(s) in directory
      
Items fixed in backend: 3
```

### Comparison: Normal Mode vs Fix Mode

| Aspect | Normal Mode | Fix Mode |
|--------|-------------|----------|
| Searches for | Files with OLD pattern (dev) | Files with NEW pattern (prod) |
| Creates copies | Yes | No |
| Renames files | Yes | No |
| Updates content | Yes (in new copies) | Yes (in existing files) |
| Use case | Initial deployment | Fixing existing files |

### Best Practices

1. **Always dry-run first**: Use `-d` to preview changes
   ```bash
   ./git_file_rename.sh --fix-content -d
   ```

2. **Fix mode is idempotent**: Safe to run multiple times on same files

3. **Combine with specific branches**: Fix only specific environments
   ```bash
   BASE_BRANCH="staging"
   BRANCH_NAME="fix-staging-refs"
   ./git_file_rename.sh --fix-content -p
   ```

4. **Use meaningful commit messages**:
   ```bash
   ./git_file_rename.sh --fix-content -p -m "Fix internal environment references in prod configs"
   ```

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

# Fix mode: only update content in existing files (no copying/renaming)
FIX_MODE=false

# Parallel execution settings (for parallel_run.sh)
PARALLEL_MAX_JOBS=""              # Empty = auto-detect CPU cores
PARALLEL_REPOS_PER_BATCH=""       # Empty = auto-calculate
PARALLEL_SCRIPT_ARGS="-p"         # Args to pass to script
PARALLEL_WORK_DIR="./parallel_work"
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
  -f, --fix-content   Fix mode: only update content in existing files
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

**7. Fix mode - update existing files:**
```bash
./git_file_rename.sh --fix-content -d  # Preview
./git_file_rename.sh --fix-content     # Execute
./git_file_rename.sh --fix-content -p  # Execute and push
```

## Use Cases

### 1. Environment Configuration Files and Directories
```bash
declare -a REPLACEMENTS=(
    "dev|prod"
    "development|production"
    "staging|prod"
)
```
Creates production versions of dev configs and entire configuration directories.
**Also replaces** cluster names, URLs, and environment references inside the files.

**Example:**
- `config.dev.yaml` → `config.prod.yaml` (file renamed + content updated)
- `environments.dev/` → `environments.prod/` (directory + all file contents updated)

### 2. Version Migration
```bash
declare -a REPLACEMENTS=(
    "v1|v2"
    "1.0|2.0"
    "old|new"
)
```
Creates next version copies of versioned files and directories.
**Also replaces** version strings in API endpoints, schema names, and documentation.

**Example:**
- `api-v1.js` → `api-v2.js` (API version strings updated in code)
- `schemas-v1/` → `schemas-v2/` (all schema files with updated version references)

### 3. Testing to Production
```bash
declare -a REPLACEMENTS=(
    "test|prod"
    "mock|real"
    "sample|live"
)
```
Duplicates test files and directories for production use.
**Also replaces** database names, API endpoints, and service URLs.

**Example:**
- `database.test.json` → `database.prod.json` (connection strings updated)
- `fixtures.test/` → `fixtures.prod/` (test data directories with updated references)

### 4. Multi-Environment Deployment
```bash
declare -a REPLACEMENTS=(
    "local|cloud"
    "onprem|aws"
    "internal|external"
)
```
**Also replaces** infrastructure references, resource names, and deployment targets.

**Example:**
- `config.local.yaml` → `config.cloud.yaml` (endpoints and credentials updated)
- `scripts.onprem/` → `scripts.aws/` (deployment scripts with updated cloud providers)

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
ℹ Base branch: main
ℹ Working branch: add-prod-configs
ℹ Authentication: token

Replacement mappings:
  'dev' → 'prod'
  'test' → 'final'

======================================================================
Processing repository: backend
======================================================================
✓ Successfully cloned
ℹ Checking out base branch: main
✓ Checked out base branch: main
ℹ Pulling latest changes from origin/main...
✓ Successfully pulled latest changes
ℹ Creating new branch: add-prod-configs

ℹ Searching for files/directories containing 'dev' in name...
  Found 3 item(s)
  Processing file: config.dev.yaml
✓ Created file: config.prod.yaml
      → Replaced content in: config.prod.yaml
  Processing file: database.dev.json
✓ Created file: database.prod.json
      → Replaced content in: database.prod.json
  Processing directory: scripts.dev/
✓ Created directory: scripts.prod/
      → Replaced content in: deploy.sh
      → Replaced content in: backup.sh
      → Replaced content in: config.json

Items copied in backend: 3

======================================================================
Git Push Operations for backend
======================================================================
ℹ Git operations in: backend
  Adding changes...
  Committing changes...
  Pushing to branch: add-prod-configs
✓ Successfully pushed changes

======================================================================
Processing repository: frontend
======================================================================
✓ Successfully cloned
ℹ Checking out base branch: main
✓ Checked out base branch: main
ℹ Pulling latest changes from origin/main...
✓ Successfully pulled latest changes
ℹ Creating new branch: add-prod-configs

ℹ Searching for files/directories containing 'dev' in name...
  Found 2 item(s)
  Processing file: env.dev.js
✓ Created file: env.prod.js
      → Replaced content in: env.prod.js
  Processing directory: configs.dev/
✓ Created directory: configs.prod/
      → Replaced content in: webpack.config.js

Items copied in frontend: 2

======================================================================
Git Push Operations for frontend
======================================================================
ℹ Git operations in: frontend
  Adding changes...
  Committing changes...
  Pushing to branch: add-prod-configs
✓ Successfully pushed changes

======================================================================
Summary
======================================================================
Total items copied: 5
Successful repositories: 2/2
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

The log file (`LOG_FILE`) tracks all operations in a single file at the top level:

**Location:** Always in the directory where you run the script (not in subdirectories)

```
# If you run from /home/user/project/
./git_file_rename.sh -p

# Log file will be at:
/home/user/project/batch_update_log.txt

# NOT at:
/home/user/project/repos_temp/batch_update_log.txt  ❌
```

**Format:**
```
[2024-02-07 10:30:15] === Git File Rename Script Started ===
[2024-02-07 10:30:15] Working directory: ./repos_temp
[2024-02-07 10:30:15] Branch name: update-strings
[2024-02-07 10:30:16] Repository: api-service | Status: CLONED | Details: New clone
[2024-02-07 10:30:18] Repository: api-service | Status: PUSHED | Details: Branch: update-strings
[2024-02-07 10:30:20] === Script Completed ===
[2024-02-07 10:30:20] Total items: 3
[2024-02-07 10:30:20] Successful repos: 1/1
```

**Parallel Execution:** All batches write to the same log file with timestamps, making it easy to track all operations in one place.

View log:
```bash
# View entire log
cat batch_update_log.txt

# Live monitoring
tail -f batch_update_log.txt

# Search for errors
grep -i error batch_update_log.txt

# View specific repository
grep "Repository: my-repo" batch_update_log.txt
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
- `git_file_rename.py` - Python version (uses same config.sh)
- `parallel_run.sh` - Parallel execution wrapper for faster batch processing
- `config.sh` - Configuration file (shared by all scripts)
- `repos.txt` - Repository list
- `README.md` - This file (includes parallel execution guide at end)
- `.gitignore` - Git exclusions
- `batch_update_log.txt` - Operation log (created on first run)

## Python Version

A Python version of the script is provided that uses the **same config.sh file** for configuration.

### Usage

```bash
# Same commands as bash version
python3 git_file_rename.py -d
python3 git_file_rename.py
python3 git_file_rename.py -p
python3 git_file_rename.py --fix-content
```

### Advantages

- **Cross-platform**: Works on Windows, macOS, Linux
- **Same config**: Uses config.sh (no separate configuration needed)
- **Same features**: All functionality identical to bash version
- **Better error handling**: More detailed Python exceptions

### Requirements

- Python 3.6 or higher
- Git 2.0 or higher

The Python version parses config.sh directly, so you only need to maintain one configuration file regardless of which version you use.

## License

[Specify your license here]

## Changelog

### Version 2.1.0 (Current)
- **Git Resiliency**: Added retry logic (3 attempts) for clone and push operations
- **Immediate Git Operations**: Commits and pushes happen immediately after each repo (not batched at end)
- **Better Error Reporting**: Shows actual git errors when operations fail
- **Python Repo Name Fix**: Uses repo name directly from repos.txt (doesn't reconstruct from URL)
- **Improved Logging**: Added detailed retry information and failure reasons

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
- **FIX_MODE**: Added fix mode to update existing files without copying
- **Content Replacement**: Automatically replaces strings inside copied files
- **Directory Support**: Recursively copies entire directories with content replacement
- **Auto Fetch/Pull**: Pulls latest changes when no local commits ahead

### Version 1.0.0
- Initial bash version
- Basic repository cloning
- Pattern-based file search and copy
- Pipe-delimited rename mappings

---

# Parallel Execution Guide

Run `git_file_rename.sh` in parallel to process multiple repositories simultaneously, dramatically speeding up batch operations.

## Quick Start

```bash
# Make executable
chmod +x parallel_run.sh

# Run with default settings (uses all CPU cores)
./parallel_run.sh

# Run with 4 parallel processes
./parallel_run.sh -j 4

# Dry run with 8 parallel processes
./parallel_run.sh -j 8 -a "-d"
```

## How It Works

1. **Splits** `repos.txt` into batches
2. **Runs** each batch in a separate background process
3. **Limits** concurrency to configured maximum
4. **Waits** for all processes to complete
5. **Combines** logs and reports results

## Command Line Options

```bash
./parallel_run.sh [OPTIONS]

Options:
  -j, --jobs NUM           Number of parallel processes (default: CPU cores)
  -n, --repos-per-batch N  Repositories per batch (default: auto-calculated)
  -r, --repo-list FILE     Repository list file (default: repos.txt)
  -a, --args "ARGS"        Arguments to pass to script (default: "-p")
  -s, --script PATH        Script to run (default: ./git_file_rename.sh)
  --clean                  Clean work directory and exit
  -h, --help               Show this help message
```

## Examples

### Basic Usage

```bash
# Default: auto-detect CPU cores
./parallel_run.sh

# Specify 4 parallel jobs
./parallel_run.sh -j 4

# Use 6 jobs with custom repo list
./parallel_run.sh -j 6 -r my_repos.txt
```

### Testing

```bash
# Dry run with 4 parallel processes
./parallel_run.sh -j 4 -a "-d"

# Dry run without pushing
./parallel_run.sh -a "-d"

# Run without pushing (local changes only)
./parallel_run.sh -a ""
```

### Advanced Usage

```bash
# Custom batch size (10 repos per batch)
./parallel_run.sh -j 4 -n 10

# Use Python script instead of bash
./parallel_run.sh -s "./git_file_rename.py" -a "-p"

# Run fix mode in parallel
./parallel_run.sh -j 6 -a "--fix-content -p"

# Custom commit message
./parallel_run.sh -a "-p -m 'Batch update from parallel run'"
```

### Environment Variables

```bash
# Set via environment variables
export MAX_PARALLEL=8
export SCRIPT_ARGS="-p -m 'Parallel batch update'"
./parallel_run.sh

# One-liner
MAX_PARALLEL=4 SCRIPT_ARGS="-d" ./parallel_run.sh
```

## Output

### Console Output

```
======================================================================
Parallel Git File Rename Runner
======================================================================
Configuration:
  Script: ./git_file_rename.sh
  Script args: -p
  Repo list: repos.txt
  Max parallel: 4
  Work directory: ./parallel_work

ℹ Setting up work directory...
✓ Found 100 repositories to process
ℹ Splitting into batches of 25 repositories each...
✓ Created 4 batches

======================================================================
Running 4 batches in parallel (max 4 concurrent)
======================================================================
ℹ Starting batch batch_000...
ℹ Starting batch batch_001...
ℹ Starting batch batch_002...
ℹ Starting batch batch_003...
ℹ Waiting for all batches to complete...

======================================================================
Parallel Execution Summary
======================================================================
Total batches: 4
✓ Completed successfully: 4
Duration: 180s (3m 0s)
Average per batch: 45s

======================================================================
Batch Results
======================================================================
✓ batch_000: 25 repos - SUCCESS
✓ batch_001: 25 repos - SUCCESS
✓ batch_002: 25 repos - SUCCESS
✓ batch_003: 25 repos - SUCCESS

ℹ Full output files available in: ./parallel_work/
  - batch_XXX_output.txt  (detailed console output per batch)
  - batch_XXX_status.txt  (SUCCESS or FAILED)

Main log file: ./batch_update_log.txt (all git operations from all batches)

✓ Parallel execution completed!
```

### Work Directory Structure

```
# Top level (where script is run)
batch_update_log.txt           # Single log file for ALL operations

# Parallel work directory
parallel_work/
├── repos_clean.txt            # Cleaned repository list
├── batch_000                  # First batch of repos
├── batch_000_output.txt       # Console output for batch 0
├── batch_000_status.txt       # SUCCESS or FAILED
├── batch_001                  # Second batch
├── batch_001_output.txt
├── batch_001_status.txt
├── ...
└── repos_batch_000/          # Cloned repos for batch 0
    ├── repo1/
    ├── repo2/
    └── ...
```

**Note:** All batches write to the same `batch_update_log.txt` at the top level with timestamps.

## Performance Tuning

### Optimal Job Count

```bash
# CPU-bound tasks (file operations)
./parallel_run.sh -j $(($(nproc) - 1))

# Network-bound tasks (git clone/push)
./parallel_run.sh -j 8

# Conservative (avoid overload)
./parallel_run.sh -j 4
```

### Batch Size Tuning

```bash
# Large batches (fewer processes, less overhead)
./parallel_run.sh -j 2 -n 50

# Small batches (more parallelism, better load balancing)
./parallel_run.sh -j 8 -n 5

# Auto-calculate (default)
./parallel_run.sh -j 4
```

### Monitoring

```bash
# In another terminal, monitor resource usage
htop

# Or monitor with top
top

# Watch progress
watch -n 5 'ls parallel_work/batch_*_status.txt 2>/dev/null | wc -l'

# Watch job count
watch -n 1 'jobs -r | wc -l'
```

## Performance Comparison

### Sequential vs Parallel

**100 repositories, ~2 minutes each:**

| Method | Time | Speedup |
|--------|------|---------|
| Sequential | 200 minutes (3h 20m) | 1x |
| 2 parallel | 100 minutes (1h 40m) | 2x |
| 4 parallel | 50 minutes | 4x |
| 8 parallel | 25 minutes | 8x |

**Actual speedup depends on:**
- Network bandwidth
- Git server rate limits
- CPU cores available
- Disk I/O speed

## Troubleshooting

### Check Batch Failures

```bash
# List failed batches
grep -l "FAILED" parallel_work/batch_*_status.txt

# View errors from failed batch
cat parallel_work/batch_001_output.txt

# Check last 20 lines of all outputs
for f in parallel_work/batch_*_output.txt; do
  echo "=== $f ==="
  tail -20 "$f"
done
```

### Resume Failed Batches

```bash
# Create new repos.txt with only failed repos
cat parallel_work/batch_001 parallel_work/batch_003 > repos_retry.txt

# Run again
./parallel_run.sh -r repos_retry.txt -j 2
```

### Clean Up

```bash
# Remove work directory
./parallel_run.sh --clean

# Or manually
rm -rf parallel_work/
```

### Common Issues

**"Too many open files"**
```bash
# Increase file descriptor limit
ulimit -n 4096

# Then run again
./parallel_run.sh -j 4
```

**"Authentication failed" in some batches**
```bash
# Ensure token/SSH is available in all processes
export GIT_AUTH_TOKEN="your_token"
./parallel_run.sh -j 4
```

**Uneven batch distribution**
```bash
# Manually set batch size
./parallel_run.sh -j 4 -n 10
```

## Best Practices

1. **Test with dry run first:**
   ```bash
   ./parallel_run.sh -j 2 -a "-d"
   ```

2. **Start with fewer jobs:**
   ```bash
   ./parallel_run.sh -j 2  # Start small
   ```

3. **Monitor the first run:**
   ```bash
   # In one terminal
   ./parallel_run.sh -j 4
   
   # In another
   htop  # or top
   ```

4. **Respect rate limits:**
   - GitHub: ~5000 requests/hour
   - Use `-j 4` or `-j 6` max for GitHub

5. **Review logs before retry:**
   ```bash
   cat batch_update_log.txt | grep -i error
   ```

6. **Keep batches reasonable:**
   - Too many batches = overhead
   - Too few batches = poor parallelism
   - Auto-calculate works well for most cases

## Integration with CI/CD

### GitHub Actions

```yaml
name: Parallel Rename
on: [workflow_dispatch]

jobs:
  rename:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run parallel rename
        env:
          GIT_AUTH_TOKEN: ${{ secrets.GH_TOKEN }}
        run: |
          chmod +x parallel_run.sh
          ./parallel_run.sh -j 4 -a "-p"
      
      - name: Upload logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: parallel-logs
          path: parallel_work/*.log
```

### Cron Job

```bash
# Add to crontab
0 2 * * * cd /path/to/git-file-rename && ./parallel_run.sh -j 4 -a "-p" >> /var/log/git-rename.log 2>&1
```

## Advanced Scenarios

### Different Args Per Batch

Create custom wrapper:
```bash
#!/bin/bash
for i in {0..3}; do
  case $i in
    0) ARGS="-p -m 'Batch 0'" ;;
    1) ARGS="-p -m 'Batch 1'" ;;
    *) ARGS="-p" ;;
  esac
  
  SCRIPT_ARGS="$ARGS" REPO_LIST_FILE="parallel_work/batch_00$i" \
    ./git_file_rename.sh &
done
wait
```

### Priority Processing

Process critical repos first:
```bash
# critical_repos.txt
repo1
repo2

# normal_repos.txt  
repo3
repo4
...

# Run critical first, then normal
./parallel_run.sh -r critical_repos.txt -j 2 -a "-p"
./parallel_run.sh -r normal_repos.txt -j 8 -a "-p"
```

### Incremental Processing

```bash
# Process only new repos
comm -13 <(sort processed_repos.txt) <(sort repos.txt) > new_repos.txt
./parallel_run.sh -r new_repos.txt -j 4 -a "-p"

# Track processed
cat new_repos.txt >> processed_repos.txt
```

## Summary

✅ **Simple**: One command to parallelize  
✅ **Fast**: 4-8x speedup typical  
✅ **Safe**: Independent processes, isolated failures  
✅ **Flexible**: Configurable jobs, batch sizes, arguments  
✅ **Observable**: Detailed logs per batch  
✅ **Resumable**: Retry only failed batches  

For most use cases:
```bash
./parallel_run.sh -j 4
```

For overnight batch jobs:
```bash
nohup ./parallel_run.sh -j 8 -a "-p" > parallel_run.out 2>&1 &
```
