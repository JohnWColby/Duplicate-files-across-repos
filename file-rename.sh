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
    local max_retries=3
    local retry_count=0
    
    if [ -d "$target_dir" ]; then
        # Repository already exists - silently continue
        log_repo_status "$(basename "$target_dir")" "EXISTS" "Using existing clone"
        return 0
    fi
    
    print_info "Cloning repository: $(basename "$url" .git)"
    
    while [ $retry_count -lt $max_retries ]; do
        if git clone "$url" "$target_dir" 2>&1 | tee /tmp/clone_output.txt; then
            print_success "Successfully cloned to: $target_dir"
            log_repo_status "$(basename "$target_dir")" "CLONED" "New clone"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Clone failed (attempt $retry_count/$max_retries), retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    print_error "Failed to clone repository after $max_retries attempts: $url"
    cat /tmp/clone_output.txt
    log_repo_status "$(basename "$url" .git)" "FAILED" "Clone failed after $max_retries attempts"
    return 1
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
    git fetch origin "$base_branch" &> /dev/null || true
    
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
        git fetch origin "$branch_name" &> /dev/null 2>&1 || true
        
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
    local max_retries=3
    
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
    
    # Push changes with retry
    echo "  Pushing to branch: $branch_name"
    local retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if git push origin "$branch_name" 2>&1 | tee /tmp/push_output.txt; then
            print_success "Successfully pushed changes"
            log_repo_status "$(basename "$repo_dir")" "PUSHED" "Branch: $branch_name"
            cd - > /dev/null
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Push failed (attempt $retry_count/$max_retries), retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    print_error "Failed to push changes after $max_retries attempts"
    cat /tmp/push_output.txt
    log_repo_status "$(basename "$repo_dir")" "PUSH_FAILED" "Branch: $branch_name"
    cd - > /dev/null
    return 1
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
        done < <(find "$repo_dir" \( -type f -o -type d \) -not -path "*/.git/*" -not -path "*/.git" -print0 2>/dev/null)
    else
        # Case-insensitive search for both files and directories
        while IFS= read -r -d '' item; do
            local itemname=$(basename "$item")
            local itemname_lower="${itemname,,}"
            local pattern_lower="${pattern,,}"
            if [[ "$itemname_lower" == *"$pattern_lower"* ]]; then
                items_array+=("$item")
            fi
        done < <(find "$repo_dir" \( -type f -o -type d \) -not -path "*/.git/*" -not -path "*/.git" -print0 2>/dev/null)
    fi
}

replace_content_in_file() {
    local file="$1"
    local old_str="$2"
    local new_str="$3"
    local case_sensitive="$4"
    local mode="${5:-verbose}"  # verbose or silent
    
    # Skip binary files
    if ! file "$file" 2>/dev/null | grep -q "text"; then
        return 1
    fi
    
    # Check if file contains the old string
    local contains_old=false
    if [ "$case_sensitive" = "true" ]; then
        if grep -q "$old_str" "$file" 2>/dev/null; then
            contains_old=true
        fi
    else
        if grep -qi "$old_str" "$file" 2>/dev/null; then
            contains_old=true
        fi
    fi
    
    # If file doesn't contain old string, nothing to do
    if [ "$contains_old" = "false" ]; then
        return 1
    fi
    
    # Escape special characters for sed
    local escaped_old=$(printf '%s\n' "$old_str" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_new=$(printf '%s\n' "$new_str" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    if [ "$case_sensitive" = "true" ]; then
        # Case-sensitive replacement
        if sed -i "s/$escaped_old/$escaped_new/g" "$file" 2>/dev/null; then
            if [ "$mode" = "verbose" ]; then
                echo "      → Replaced content in: $(basename "$file")"
            fi
            return 0
        fi
    else
        # Case-insensitive replacement
        if sed -i "s/$escaped_old/$escaped_new/gI" "$file" 2>/dev/null; then
            if [ "$mode" = "verbose" ]; then
                echo "      → Replaced content in: $(basename "$file")"
            fi
            return 0
        fi
    fi
    
    return 1
}

replace_content_in_directory() {
    local dir="$1"
    local old_str="$2"
    local new_str="$3"
    local case_sensitive="$4"
    
    # Find all files in the directory (excluding .git)
    while IFS= read -r -d '' file; do
        replace_content_in_file "$file" "$old_str" "$new_str" "$case_sensitive"
    done < <(find "$dir" -type f -not -path "*/.git/*" -print0 2>/dev/null)
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
            echo "    [DRY RUN] Would replace '$old_str' → '$new_str' in all files"
        else
            echo "    [DRY RUN] Would copy file to: $new_itemname"
            echo "    [DRY RUN] Would replace '$old_str' → '$new_str' in file contents"
        fi
        return 0
    else
        # Handle directories
        if [ -d "$original_item" ]; then
            if cp -r "$original_item" "$new_item"; then
                print_success "Created directory: $new_itemname/"
                
                # Replace content within all files in the copied directory
                replace_content_in_directory "$new_item" "$old_str" "$new_str" "$case_sensitive"
                
                return 0
            else
                print_error "Failed to copy directory"
                return 1
            fi
        # Handle files
        elif [ -f "$original_item" ]; then
            if cp "$original_item" "$new_item"; then
                print_success "Created file: $new_itemname"
                
                # Replace content within the copied file
                replace_content_in_file "$new_item" "$old_str" "$new_str" "$case_sensitive"
                
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
    
    # Use global variable for return value
    PROCESS_RESULT=0
    
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
    
    # Set global result
    PROCESS_RESULT=$files_copied
    return 0
}

process_repository_fix_mode() {
    local repo_input="$1"
    local dry_run="$2"
    
    # Use global variable for return value
    PROCESS_RESULT=0
    
    # Construct full repository URL
    local repo_url=$(construct_repo_url "$repo_input")
    local repo_name=$(get_repo_name "$repo_url")
    local repo_dir="$WORK_DIR/$repo_name"
    
    print_header "Processing repository (FIX MODE): $repo_name"
    
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
    
    local files_fixed=0
    
    # Process each replacement - search for files containing the NEW value
    for pair in "${REPLACEMENTS[@]}"; do
        # Split by pipe character
        IFS='|' read -r old_str new_str <<< "$pair"
        
        # Trim whitespace
        old_str=$(echo "$old_str" | xargs)
        new_str=$(echo "$new_str" | xargs)
        
        echo ""
        print_info "Searching for files/directories containing '$new_str' in name (to fix content)..."
        
        # Find files/directories containing the NEW string (value)
        local matching_items=()
        find_files_and_dirs_with_pattern "$repo_dir" "$new_str" "$CASE_SENSITIVE" matching_items
        
        if [ ${#matching_items[@]} -eq 0 ]; then
            echo "  No files or directories found with '$new_str' in name"
            continue
        fi
        
        echo "  Found ${#matching_items[@]} item(s) to check for content replacement"
        
        # Process each matching item - replace OLD string in content
        for item in "${matching_items[@]}"; do
            local rel_path="${item#$repo_dir/}"
            
            # Check if it's a file or directory
            if [ -d "$item" ]; then
                echo "  Checking directory: $rel_path/"
                
                if [ "$dry_run" = "true" ]; then
                    echo "    [DRY RUN] Would replace '$old_str' → '$new_str' in all files"
                    files_fixed=$((files_fixed + 1))
                else
                    # Replace content in all files in the directory
                    local replaced_count=0
                    while IFS= read -r -d '' file; do
                        if replace_content_in_file "$file" "$old_str" "$new_str" "$CASE_SENSITIVE" "silent"; then
                            replaced_count=$((replaced_count + 1))
                        fi
                    done < <(find "$item" -type f -not -path "*/.git/*" -print0 2>/dev/null)
                    
                    if [ $replaced_count -gt 0 ]; then
                        print_success "Fixed content in $replaced_count file(s) in directory"
                        files_fixed=$((files_fixed + 1))
                    else
                        echo "    No changes needed in directory"
                    fi
                fi
            else
                echo "  Checking file: $rel_path"
                
                if [ "$dry_run" = "true" ]; then
                    # Check if file contains the old string
                    if grep -q "$old_str" "$item" 2>/dev/null; then
                        echo "    [DRY RUN] Would replace '$old_str' → '$new_str' in file"
                        files_fixed=$((files_fixed + 1))
                    else
                        echo "    No changes needed"
                    fi
                else
                    if replace_content_in_file "$item" "$old_str" "$new_str" "$CASE_SENSITIVE" "verbose"; then
                        files_fixed=$((files_fixed + 1))
                    else
                        echo "    No changes needed"
                    fi
                fi
            fi
        done
    done
    
    echo ""
    echo "Items fixed in $repo_name: $files_fixed"
    
    # Set global result
    PROCESS_RESULT=$files_fixed
    return 0
}

#############################################################
# Main Script
#############################################################

main() {
    local dry_run="false"
    local push_changes="$AUTO_PUSH"
    local commit_message="$COMMIT_MESSAGE"
    local fix_mode="$FIX_MODE"
    
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
            -f|--fix-content|--fix)
                fix_mode="true"
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -d, --dry-run       Preview changes without copying files"
                echo "  -p, --push          Commit and push changes after copying"
                echo "  -m, --message MSG   Commit message (used with --push)"
                echo "  -f, --fix-content   Fix mode: only update content in existing files"
                echo "                      that match the new pattern (no copying)"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Configuration:"
                echo "  Edit config.sh to configure repositories, replacements,"
                echo "  authentication, and other settings."
                echo ""
                echo "Fix Mode:"
                echo "  When --fix-content is used, the script searches for files/directories"
                echo "  containing the mapping VALUES (new strings) and replaces any"
                echo "  occurrences of the mapping KEYS (old strings) within those files."
                echo "  This is useful for fixing files that were copied before content"
                echo "  replacement was added to the script."
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
    
    if [ "$fix_mode" = "true" ]; then
        echo "MODE: Fix existing files (content replacement only)"
    else
        echo "MODE: Copy and rename files/directories"
    fi
    
    echo "Config file: $CONFIG_FILE"
    echo "Repository list: $REPO_LIST_FILE"
    echo "Working directory: $WORK_DIR"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    log_to_file "=== Git File Rename Script Started ==="
    log_to_file "Mode: $([ "$fix_mode" = "true" ] && echo "Fix content only" || echo "Copy and rename")"
    log_to_file "Working directory: $WORK_DIR"
    log_to_file "Base branch: ${BASE_BRANCH:-default}"
    log_to_file "Working branch: ${BRANCH_NAME:-current}"
    log_to_file "Dry run: $dry_run"
    log_to_file "Push changes: $push_changes"
    
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
    
    while IFS= read -r repo_input; do
        # Skip comments and empty lines
        [[ "$repo_input" =~ ^#.*$ ]] && continue
        [[ -z "$repo_input" ]] && continue
        
        total_repos=$((total_repos + 1))
        
        echo ""
        
        PROCESS_RESULT=0
        if [ "$fix_mode" = "true" ]; then
            # Fix mode: update content in existing files
            if process_repository_fix_mode "$repo_input" "$dry_run"; then
                successful_repos=$((successful_repos + 1))
                total_files_copied=$((total_files_copied + PROCESS_RESULT))
                
                # Git operations immediately after processing
                if [ "$PROCESS_RESULT" -gt 0 ] && [ "$push_changes" = "true" ] && [ "$dry_run" = "false" ]; then
                    local repo_url=$(construct_repo_url "$repo_input")
                    local repo_name=$(get_repo_name "$repo_url")
                    local repo_dir="$WORK_DIR/$repo_name"
                    
                    echo ""
                    print_header "Git Push Operations for $repo_name"
                    git_add_commit_push "$repo_dir" "$commit_message" "$BRANCH_NAME"
                fi
            fi
        else
            # Normal mode: copy and rename
            if process_repository "$repo_input" "$dry_run"; then
                successful_repos=$((successful_repos + 1))
                total_files_copied=$((total_files_copied + PROCESS_RESULT))
                
                # Git operations immediately after processing
                if [ "$PROCESS_RESULT" -gt 0 ] && [ "$push_changes" = "true" ] && [ "$dry_run" = "false" ]; then
                    local repo_url=$(construct_repo_url "$repo_input")
                    local repo_name=$(get_repo_name "$repo_url")
                    local repo_dir="$WORK_DIR/$repo_name"
                    
                    echo ""
                    print_header "Git Push Operations for $repo_name"
                    git_add_commit_push "$repo_dir" "$commit_message" "$BRANCH_NAME"
                fi
            fi
        fi
    done < "$REPO_LIST_FILE"
    
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
