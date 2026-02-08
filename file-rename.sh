#!/bin/bash

#############################################################
# Git File Rename Script
# 
# Clones repositories and creates renamed copies of files
# based on string substitution patterns.
#############################################################

set -e  # Exit on error

# Source the config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

source "$CONFIG_FILE"

# Use REPLACEMENTS array (preferred name)
if [ ${#REPLACEMENTS[@]} -eq 0 ]; then
    echo "Error: REPLACEMENTS array is empty in config.sh"
    exit 1
fi

#############################################################
# Color Codes
#############################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

#############################################################
# Logging Functions
#############################################################

log_to_file() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

log_repo_status() {
    local repo_name="$1"
    local status="$2"
    local details="$3"
    
    log_to_file "Repository: $repo_name | Status: $status | Details: $details"
}

#############################################################
# Helper Functions
#############################################################

print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    [ "$VERBOSE_LOGGING" = "true" ] && log_to_file "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_to_file "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    [ "$VERBOSE_LOGGING" = "true" ] && log_to_file "WARNING: $1"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    [ "$VERBOSE" = "true" ] && log_to_file "INFO: $1"
}

#############################################################
# Authentication Functions
#############################################################

setup_git_credentials() {
    if [ "$GIT_AUTH_METHOD" = "token" ]; then
        if [ -z "$GIT_AUTH_TOKEN" ]; then
            print_error "GIT_AUTH_METHOD is 'token' but GIT_AUTH_TOKEN is not set"
            print_info "Set GIT_AUTH_TOKEN in config.sh or export it as an environment variable"
            exit 1
        fi
        
        if [ -z "$GIT_USERNAME" ]; then
            print_error "GIT_AUTH_METHOD is 'token' but GIT_USERNAME is not set"
            exit 1
        fi
        
        # Configure git credential helper to use token
        git config --global credential.helper store
        
        print_success "Git authentication configured for token-based access"
    elif [ "$GIT_AUTH_METHOD" = "ssh" ]; then
        # Check if ssh-agent is running
        if ! ssh-add -l &>/dev/null; then
            print_warning "SSH agent not running or no keys loaded"
            print_info "You may need to run: ssh-add ~/.ssh/id_rsa"
        else
            print_success "SSH authentication detected"
        fi
    elif [ "$GIT_AUTH_METHOD" = "none" ]; then
        print_info "No authentication configured (using system defaults)"
    else
        print_error "Invalid GIT_AUTH_METHOD: $GIT_AUTH_METHOD"
        print_info "Valid options: token, ssh, none"
        exit 1
    fi
}

construct_repo_url() {
    local repo_input="$1"
    
    # If it's already a full URL, return as-is
    if [[ "$repo_input" =~ ^https?:// ]] || [[ "$repo_input" =~ ^git@ ]]; then
        echo "$repo_input"
        return
    fi
    
    # Otherwise, combine with base URL
    local repo_name="$repo_input"
    
    # Remove trailing .git if present in repo name
    repo_name="${repo_name%.git}"
    
    # Construct URL based on auth method
    if [ "$GIT_AUTH_METHOD" = "token" ]; then
        # Use token authentication in URL
        local base_url="${GIT_BASE_URL#https://}"
        echo "https://${GIT_USERNAME}:${GIT_AUTH_TOKEN}@${base_url}/${repo_name}.git"
    elif [ "$GIT_AUTH_METHOD" = "ssh" ]; then
        # Convert HTTPS base URL to SSH format if needed
        if [[ "$GIT_BASE_URL" =~ ^https://github.com/(.+)$ ]]; then
            local org="${BASH_REMATCH[1]}"
            echo "git@github.com:${org}/${repo_name}.git"
        elif [[ "$GIT_BASE_URL" =~ ^https://(.+)/(.+)$ ]]; then
            local host="${BASH_REMATCH[1]}"
            local org="${BASH_REMATCH[2]}"
            echo "git@${host}:${org}/${repo_name}.git"
        else
            echo "${GIT_BASE_URL}/${repo_name}.git"
        fi
    else
        echo "${GIT_BASE_URL}/${repo_name}.git"
    fi
}

#############################################################
# Validation Functions
#############################################################

validate_config() {
    local errors=0
    
    # Check for repository list file
    if [ ! -f "$REPO_LIST_FILE" ]; then
        print_error "Repository list file not found: $REPO_LIST_FILE"
        errors=$((errors + 1))
    fi
    
    # Check if replacements are defined
    if [ ${#REPLACEMENTS[@]} -eq 0 ]; then
        print_error "No replacements defined in REPLACEMENTS array"
        errors=$((errors + 1))
    fi
    
    # Check for git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        errors=$((errors + 1))
    fi
    
    # Validate authentication if using token method
    if [ "$GIT_AUTH_METHOD" = "token" ]; then
        if [ -z "$GIT_AUTH_TOKEN" ]; then
            print_error "GIT_AUTH_TOKEN is required when GIT_AUTH_METHOD='token'"
            errors=$((errors + 1))
        fi
        if [ -z "$GIT_USERNAME" ]; then
            print_error "GIT_USERNAME is required when GIT_AUTH_METHOD='token'"
            errors=$((errors + 1))
        fi
    fi
    
    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Configuration validation failed with $errors error(s)"
        exit 1
    fi
    
    print_success "Configuration validated"
}

#############################################################
# Git Functions
#############################################################

get_repo_name() {
    local url="$1"
    local name=$(basename "$url" .git)
    echo "$name"
}

clone_repository() {
    local url="$1"
    local target_dir="$2"
    
    if [ -d "$target_dir" ]; then
        # Repository already exists - silently continue
        log_repo_status "$(basename "$target_dir")" "EXISTS" "Using existing clone"
        return 0
    fi
    
    print_info "Cloning repository: $(basename "$url" .git)"
    if git clone "$url" "$target_dir" &> /dev/null; then
        print_success "Successfully cloned to: $target_dir"
        log_repo_status "$(basename "$target_dir")" "CLONED" "New clone"
        return 0
    else
        print_error "Failed to clone repository: $url"
        log_repo_status "$(basename "$url" .git)" "FAILED" "Clone failed"
        return 1
    fi
}

checkout_base_branch() {
    local repo_dir="$1"
    local base_branch="$2"
    
    # If no base branch specified, use whatever is current
    if [ -z "$base_branch" ]; then
        return 0
    fi
    
    cd "$repo_dir"
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Check if we need to checkout
    local need_checkout=true
    if [ "$current_branch" = "$base_branch" ]; then
        print_info "Already on base branch: $base_branch"
        need_checkout=false
    fi
    
    # Checkout if needed
    if [ "$need_checkout" = "true" ]; then
        print_info "Checking out base branch: $base_branch"
        
        # Try to checkout the branch
        if git checkout "$base_branch" &> /dev/null; then
            print_success "Checked out base branch: $base_branch"
        else
            # Branch might not exist locally, try fetching
            print_info "Branch not found locally, trying to fetch from remote..."
            if git fetch origin "$base_branch:$base_branch" &> /dev/null && git checkout "$base_branch" &> /dev/null; then
                print_success "Fetched and checked out base branch: $base_branch"
            else
                print_error "Failed to checkout base branch: $base_branch"
                print_warning "Continuing with current branch: $current_branch"
                cd - > /dev/null
                return 1
            fi
        fi
    fi
    
    # Now we're on the base branch - check if we should pull
    # Fetch the latest remote information
    git fetch origin "$base_branch" &> /dev/null
    
    # Check if local branch has commits ahead of remote
    local commits_ahead=$(git rev-list --count origin/"$base_branch"..HEAD 2>/dev/null || echo "0")
    
    if [ "$commits_ahead" = "0" ]; then
        # No local commits ahead, safe to pull
        print_info "Pulling latest changes from origin/$base_branch..."
        if git pull origin "$base_branch" &> /dev/null; then
            print_success "Successfully pulled latest changes"
        else
            print_warning "Failed to pull changes (continuing anyway)"
        fi
    else
        print_info "Local branch has $commits_ahead commit(s) ahead of remote - skipping pull"
    fi
    
    cd - > /dev/null
    return 0
}

create_or_checkout_branch() {
    local repo_dir="$1"
    local branch_name="$2"
    
    # If no branch name specified, stay on current branch
    if [ -z "$branch_name" ]; then
        return 0
    fi
    
    cd "$repo_dir"
    
    # Check if branch already exists locally
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        print_info "Checking out existing branch: $branch_name"
        git checkout "$branch_name" &> /dev/null
        
        # Fetch and check if we should pull
        git fetch origin "$branch_name" &> /dev/null 2>&1
        
        # Check if local branch has commits ahead of remote
        local commits_ahead=$(git rev-list --count origin/"$branch_name"..HEAD 2>/dev/null || echo "0")
        
        if [ "$commits_ahead" = "0" ]; then
            # No local commits ahead, safe to pull
            print_info "Pulling latest changes from origin/$branch_name..."
            if git pull origin "$branch_name" &> /dev/null 2>&1; then
                print_success "Successfully pulled latest changes"
            else
                print_info "No remote tracking branch or pull not needed"
            fi
        else
            print_info "Local branch has $commits_ahead commit(s) ahead of remote - skipping pull"
        fi
    else
        # Branch doesn't exist locally
        if [ "$AUTO_CREATE_BRANCH" = "true" ]; then
            print_info "Creating new branch: $branch_name"
            git checkout -b "$branch_name" &> /dev/null
        else
            print_warning "Branch $branch_name does not exist and AUTO_CREATE_BRANCH is false"
            cd - > /dev/null
            return 1
        fi
    fi
    
    cd - > /dev/null
    return 0
}

git_add_commit_push() {
    local repo_dir="$1"
    local commit_message="$2"
    local branch_name="$3"
    
    cd "$repo_dir"
    
    # Check if there are changes
    if [ -z "$(git status --porcelain)" ]; then
        print_info "No changes to commit"
        cd - > /dev/null
        return 0
    fi
    
    print_info "Git operations in: $(basename "$repo_dir")"
    
    # Add all changes
    echo "  Adding changes..."
    git add -A
    
    # Commit changes
    echo "  Committing changes..."
    git commit -m "$commit_message"
    
    # Use provided branch or get current branch
    if [ -z "$branch_name" ]; then
        branch_name=$(git branch --show-current)
    fi
    
    # Push changes
    echo "  Pushing to branch: $branch_name"
    if git push origin "$branch_name"; then
        print_success "Successfully pushed changes"
        log_repo_status "$(basename "$repo_dir")" "PUSHED" "Branch: $branch_name"
        cd - > /dev/null
        return 0
    else
        print_error "Failed to push changes"
        log_repo_status "$(basename "$repo_dir")" "PUSH_FAILED" "Branch: $branch_name"
        cd - > /dev/null
        return 1
    fi
}

#############################################################
# File Processing Functions
#############################################################

find_files_and_dirs_with_pattern() {
    local repo_dir="$1"
    local pattern="$2"
    local case_sensitive="$3"
    local -n items_array=$4  # nameref to return array
    
    items_array=()
    
    if [ "$case_sensitive" = "true" ]; then
        # Case-sensitive search for both files and directories
        while IFS= read -r -d '' item; do
            local itemname=$(basename "$item")
            if [[ "$itemname" == *"$pattern"* ]]; then
                items_array+=("$item")
            fi
        done < <(find "$repo_dir" \( -type f -o -type d \) -not -path "*/.git/*" -not -path "*/.git" -print0)
    else
        # Case-insensitive search for both files and directories
        while IFS= read -r -d '' item; do
            local itemname=$(basename "$item")
            local itemname_lower="${itemname,,}"
            local pattern_lower="${pattern,,}"
            if [[ "$itemname_lower" == *"$pattern_lower"* ]]; then
                items_array+=("$item")
            fi
        done < <(find "$repo_dir" \( -type f -o -type d \) -not -path "*/.git/*" -not -path "*/.git" -print0)
    fi
}

create_renamed_copy() {
    local original_item="$1"
    local old_str="$2"
    local new_str="$3"
    local case_sensitive="$4"
    local dry_run="$5"
    
    local dir=$(dirname "$original_item")
    local itemname=$(basename "$original_item")
    
    # Perform replacement based on case sensitivity
    local new_itemname
    if [ "$case_sensitive" = "true" ]; then
        new_itemname="${itemname//$old_str/$new_str}"
    else
        # Case-insensitive replacement using sed
        new_itemname=$(echo "$itemname" | sed "s/$old_str/$new_str/gI")
    fi
    
    # Skip if name would be the same
    if [ "$itemname" = "$new_itemname" ]; then
        return 1
    fi
    
    local new_item="$dir/$new_itemname"
    
    # Check if target already exists
    if [ -e "$new_item" ]; then
        echo "    $(print_warning "Target already exists: $new_itemname")"
        return 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        if [ -d "$original_item" ]; then
            echo "    [DRY RUN] Would copy directory to: $new_itemname/"
        else
            echo "    [DRY RUN] Would copy file to: $new_itemname"
        fi
        return 0
    else
        # Handle directories
        if [ -d "$original_item" ]; then
            if cp -r "$original_item" "$new_item"; then
                print_success "Created directory: $new_itemname/"
                return 0
            else
                print_error "Failed to copy directory"
                return 1
            fi
        # Handle files
        elif [ -f "$original_item" ]; then
            if cp "$original_item" "$new_item"; then
                print_success "Created file: $new_itemname"
                return 0
            else
                print_error "Failed to copy file"
                return 1
            fi
        else
            print_warning "Skipping: neither file nor directory: $itemname"
            return 1
        fi
    fi
}

#############################################################
# Main Processing Functions
#############################################################

process_repository() {
    local repo_input="$1"
    local dry_run="$2"
    
    # Construct full repository URL
    local repo_url=$(construct_repo_url "$repo_input")
    local repo_name=$(get_repo_name "$repo_url")
    local repo_dir="$WORK_DIR/$repo_name"
    
    print_header "Processing repository: $repo_name"
    
    # Clone repository if needed
    if ! clone_repository "$repo_url" "$repo_dir"; then
        return 1
    fi
    
    # Checkout base branch if specified
    if [ -n "$BASE_BRANCH" ]; then
        checkout_base_branch "$repo_dir" "$BASE_BRANCH"
    fi
    
    # Create or checkout working branch if specified
    if [ -n "$BRANCH_NAME" ]; then
        if ! create_or_checkout_branch "$repo_dir" "$BRANCH_NAME"; then
            print_warning "Could not create/checkout branch, continuing on current branch"
        fi
    fi
    
    local files_copied=0
    
    # Process each replacement
    for pair in "${REPLACEMENTS[@]}"; do
        # Split by pipe character
        IFS='|' read -r old_str new_str <<< "$pair"
        
        # Trim whitespace
        old_str=$(echo "$old_str" | xargs)
        new_str=$(echo "$new_str" | xargs)
        
        echo ""
        print_info "Searching for files/directories containing '$old_str' in name..."
        
        # Find matching files and directories
        local matching_items=()
        find_files_and_dirs_with_pattern "$repo_dir" "$old_str" "$CASE_SENSITIVE" matching_items
        
        if [ ${#matching_items[@]} -eq 0 ]; then
            echo "  No files or directories found with '$old_str' in name"
            continue
        fi
        
        echo "  Found ${#matching_items[@]} item(s)"
        
        # Process each matching item
        for item in "${matching_items[@]}"; do
            local rel_path="${item#$repo_dir/}"
            
            # Determine if file or directory
            if [ -d "$item" ]; then
                echo "  Processing directory: $rel_path/"
            else
                echo "  Processing file: $rel_path"
            fi
            
            if create_renamed_copy "$item" "$old_str" "$new_str" "$CASE_SENSITIVE" "$dry_run"; then
                files_copied=$((files_copied + 1))
            fi
        done
    done
    
    echo ""
    echo "Items copied in $repo_name: $files_copied"
    
    # Return the count
    return $files_copied
}

#############################################################
# Main Script
#############################################################

main() {
    local dry_run="false"
    local push_changes="$AUTO_PUSH"
    local commit_message="$COMMIT_MESSAGE"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                dry_run="true"
                shift
                ;;
            -p|--push)
                push_changes="true"
                shift
                ;;
            -m|--message)
                commit_message="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -d, --dry-run       Preview changes without copying files"
                echo "  -p, --push          Commit and push changes after copying"
                echo "  -m, --message MSG   Commit message (used with --push)"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Configuration:"
                echo "  Edit config.sh to configure repositories, replacements,"
                echo "  authentication, and other settings."
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header "Git File Rename - Starting"
    
    echo "Config file: $CONFIG_FILE"
    echo "Repository list: $REPO_LIST_FILE"
    echo "Working directory: $WORK_DIR"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    log_to_file "=== Git File Rename Script Started ==="
    log_to_file "Working directory: $WORK_DIR"
    log_to_file "Base branch: ${BASE_BRANCH:-default}"
    log_to_file "Working branch: ${BRANCH_NAME:-current}"
    log_to_file "Dry run: $dry_run"
    
    # Setup authentication
    setup_git_credentials
    
    # Validate configuration
    validate_config
    
    # Count repositories
    local repo_count=$(grep -v '^#' "$REPO_LIST_FILE" | grep -v '^[[:space:]]*$' | wc -l)
    echo ""
    print_info "Repositories to process: $repo_count"
    print_info "Replacements: ${#REPLACEMENTS[@]}"
    print_info "Case sensitive: $CASE_SENSITIVE"
    print_info "Base branch: ${BASE_BRANCH:-current}"
    print_info "Working branch: ${BRANCH_NAME:-current}"
    print_info "Authentication: $GIT_AUTH_METHOD"
    
    # Show replacements
    echo ""
    echo "Replacement mappings:"
    for pair in "${REPLACEMENTS[@]}"; do
        IFS='|' read -r old_str new_str <<< "$pair"
        old_str=$(echo "$old_str" | xargs)
        new_str=$(echo "$new_str" | xargs)
        echo "  '$old_str' → '$new_str'"
    done
    
    # Create working directory if needed
    mkdir -p "$WORK_DIR"
    
    # Process each repository
    local total_files_copied=0
    local successful_repos=0
    local total_repos=0
    
    local repos_with_changes=()
    
    while IFS= read -r repo_input; do
        # Skip comments and empty lines
        [[ "$repo_input" =~ ^#.*$ ]] && continue
        [[ -z "$repo_input" ]] && continue
        
        total_repos=$((total_repos + 1))
        
        echo ""
        if process_repository "$repo_input" "$dry_run"; then
            local copied=$?
            successful_repos=$((successful_repos + 1))
            total_files_copied=$((total_files_copied + copied))
            
            if [ $copied -gt 0 ]; then
                local repo_url=$(construct_repo_url "$repo_input")
                local repo_name=$(get_repo_name "$repo_url")
                repos_with_changes+=("$repo_name")
            fi
        fi
    done < "$REPO_LIST_FILE"
    
    # Git operations if requested
    if [ "$push_changes" = "true" ] && [ "$dry_run" = "false" ]; then
        echo ""
        print_header "Git Push Operations"
        
        for repo_name in "${repos_with_changes[@]}"; do
            local repo_dir="$WORK_DIR/$repo_name"
            echo ""
            git_add_commit_push "$repo_dir" "$commit_message" "$BRANCH_NAME"
        done
    fi
    
    # Summary
    echo ""
    print_header "Summary"
    
    echo "Total items copied: $total_files_copied"
    echo "Successful repositories: $successful_repos/$total_repos"
    echo "Log file: $LOG_FILE"
    
    if [ "$dry_run" = "true" ]; then
        echo ""
        print_warning "[DRY RUN MODE] No files were actually copied or committed"
    fi
    
    log_to_file "=== Script Completed ==="
    log_to_file "Total items copied: $total_files_copied"
    log_to_file "Successful repos: $successful_repos/$total_repos"
    
    echo ""
    if [ $successful_repos -eq $total_repos ]; then
        print_success "Operation completed successfully!"
        exit 0
    else
        print_warning "Operation completed with some errors"
        exit 1
    fi
}

# Run main function
main "$@"
