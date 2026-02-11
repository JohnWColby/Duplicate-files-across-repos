#!/bin/bash

#############################################################
# Parallel Git File Rename Runner
# 
# Runs git_file_rename.sh in parallel across multiple processes
# to speed up batch operations on many repositories.
#############################################################

set -e

#############################################################
# Load Configuration
#############################################################

# Try to load config.sh if it exists
if [ -f "config.sh" ]; then
    source config.sh
fi

#############################################################
# Configuration (can be overridden by config.sh or command line)
#############################################################

# Number of parallel processes (default: number of CPU cores)
MAX_PARALLEL=${PARALLEL_MAX_JOBS:-${MAX_PARALLEL:-$(nproc 2>/dev/null || echo 4)}}

# Script to run
SCRIPT="./git_file_rename.sh"

# Repository list file
REPO_LIST_FILE=${REPO_LIST_FILE:-"repos.txt"}

# Work directory for temporary files
WORK_DIR=${PARALLEL_WORK_DIR:-"./parallel_work"}

# Script arguments (e.g., "-p" for push, "-d" for dry-run)
SCRIPT_ARGS=${PARALLEL_SCRIPT_ARGS:-${SCRIPT_ARGS:-"-p"}}

# Repositories per batch (auto-calculated if not set)
REPOS_PER_BATCH=${PARALLEL_REPOS_PER_BATCH:-${REPOS_PER_BATCH:-""}}

#############################################################
# Color Codes
#############################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

#############################################################
# Validation
#############################################################

validate_setup() {
    local errors=0
    
    if [ ! -f "$SCRIPT" ]; then
        print_error "Script not found: $SCRIPT"
        errors=$((errors + 1))
    fi
    
    if [ ! -x "$SCRIPT" ]; then
        print_error "Script is not executable: $SCRIPT"
        print_info "Run: chmod +x $SCRIPT"
        errors=$((errors + 1))
    fi
    
    if [ ! -f "$REPO_LIST_FILE" ]; then
        print_error "Repository list not found: $REPO_LIST_FILE"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        exit 1
    fi
}

#############################################################
# Main Functions
#############################################################

cleanup_previous_run() {
    if [ -d "$WORK_DIR" ]; then
        print_info "Cleaning up previous run..."
        rm -rf "$WORK_DIR"
    fi
}

setup_work_directory() {
    print_info "Setting up work directory..."
    mkdir -p "$WORK_DIR"
    
    # Extract non-comment, non-empty lines
    grep -v '^#' "$REPO_LIST_FILE" | grep -v '^[[:space:]]*$' > "$WORK_DIR/repos_clean.txt" || true
    
    local total_repos=$(wc -l < "$WORK_DIR/repos_clean.txt")
    
    if [ "$total_repos" -eq 0 ]; then
        print_error "No repositories found in $REPO_LIST_FILE"
        exit 1
    fi
    
    print_success "Found $total_repos repositories to process"
    
    echo "$total_repos"
}

split_repositories() {
    local total_repos=$1
    
    # Calculate repos per batch
    if [ -z "$REPOS_PER_BATCH" ]; then
        REPOS_PER_BATCH=$(( (total_repos + MAX_PARALLEL - 1) / MAX_PARALLEL ))
    fi
    
    print_info "Splitting into batches of $REPOS_PER_BATCH repositories each..."
    
    cd "$WORK_DIR"
    split -l "$REPOS_PER_BATCH" repos_clean.txt batch_ -d -a 3
    cd - > /dev/null
    
    local batch_count=$(ls "$WORK_DIR"/batch_* 2>/dev/null | wc -l)
    print_success "Created $batch_count batches"
    
    echo "$batch_count"
}

run_parallel() {
    local batch_count=$1
    
    print_header "Running $batch_count batches in parallel (max $MAX_PARALLEL concurrent)"
    
    local start_time=$(date +%s)
    local current_jobs=0
    local completed_batches=0
    local failed_batches=0
    
    # Process each batch
    for batch_file in "$WORK_DIR"/batch_*; do
        local batch_name=$(basename "$batch_file")
        local batch_num="${batch_name#batch_}"
        
        # Wait if at max jobs
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
            sleep 1
        done
        
        print_info "Starting batch $batch_name..."
        
        # Run batch in background
        (
            # Set environment variables for this batch
            export REPO_LIST_FILE="$batch_file"
            # Each batch writes to the main log file (thread-safe enough for our use)
            export LOG_FILE="$(pwd)/batch_update_log.txt"
            export WORK_DIR="$WORK_DIR/repos_${batch_name}"
            
            # Run the script
            if $SCRIPT $SCRIPT_ARGS > "$WORK_DIR/${batch_name}_output.txt" 2>&1; then
                echo "SUCCESS" > "$WORK_DIR/${batch_name}_status.txt"
            else
                echo "FAILED" > "$WORK_DIR/${batch_name}_status.txt"
            fi
        ) &
        
        current_jobs=$((current_jobs + 1))
    done
    
    # Wait for all background jobs to complete
    print_info "Waiting for all batches to complete..."
    wait
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Count successes and failures
    for batch_file in "$WORK_DIR"/batch_*; do
        local batch_name=$(basename "$batch_file")
        local status_file="$WORK_DIR/${batch_name}_status.txt"
        
        if [ -f "$status_file" ]; then
            local status=$(cat "$status_file")
            if [ "$status" = "SUCCESS" ]; then
                completed_batches=$((completed_batches + 1))
            else
                failed_batches=$((failed_batches + 1))
            fi
        else
            failed_batches=$((failed_batches + 1))
        fi
    done
    
    # Report results
    echo ""
    print_header "Parallel Execution Summary"
    
    echo "Total batches: $batch_count"
    print_success "Completed successfully: $completed_batches"
    
    if [ $failed_batches -gt 0 ]; then
        print_error "Failed: $failed_batches"
    fi
    
    echo "Duration: ${duration}s ($(($duration / 60))m $(($duration % 60))s)"
    echo "Average per batch: $((duration / batch_count))s"
}

show_batch_results() {
    echo ""
    print_header "Batch Results"
    
    for batch_file in "$WORK_DIR"/batch_*; do
        local batch_name=$(basename "$batch_file")
        local status_file="$WORK_DIR/${batch_name}_status.txt"
        local output_file="$WORK_DIR/${batch_name}_output.txt"
        local repo_count=$(wc -l < "$batch_file")
        
        if [ -f "$status_file" ]; then
            local status=$(cat "$status_file")
            
            if [ "$status" = "SUCCESS" ]; then
                echo -e "${GREEN}✓${NC} $batch_name: $repo_count repos - SUCCESS"
            else
                echo -e "${RED}✗${NC} $batch_name: $repo_count repos - FAILED"
                
                # Show error summary if available
                if [ -f "$output_file" ]; then
                    echo "  Error preview:"
                    tail -5 "$output_file" | sed 's/^/    /'
                fi
            fi
        else
            echo -e "${YELLOW}?${NC} $batch_name: $repo_count repos - UNKNOWN"
        fi
    done
    
    echo ""
    print_info "Full output files available in: $WORK_DIR/"
    echo "  - batch_XXX_output.txt  (console output per batch)"
    echo "  - batch_XXX_status.txt  (SUCCESS or FAILED)"
    echo ""
    print_info "Main log file: $(pwd)/batch_update_log.txt"
    echo "  (All git operations from all batches)"
}
    print_info "Combined log file: $(pwd)/batch_update_log.txt"
}

#############################################################
# Main Script
#############################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--jobs)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -n|--repos-per-batch)
                REPOS_PER_BATCH="$2"
                shift 2
                ;;
            -r|--repo-list)
                REPO_LIST_FILE="$2"
                shift 2
                ;;
            -a|--args)
                SCRIPT_ARGS="$2"
                shift 2
                ;;
            -s|--script)
                SCRIPT="$2"
                shift 2
                ;;
            --clean)
                print_info "Cleaning work directory..."
                rm -rf "$WORK_DIR"
                print_success "Cleaned: $WORK_DIR"
                exit 0
                ;;
            -h|--help)
                cat << HELP
Usage: $0 [OPTIONS]

Runs git_file_rename.sh in parallel to speed up batch operations.

Options:
  -j, --jobs NUM           Number of parallel processes (default: CPU cores)
  -n, --repos-per-batch N  Repositories per batch (default: auto-calculated)
  -r, --repo-list FILE     Repository list file (default: repos.txt)
  -a, --args "ARGS"        Arguments to pass to script (default: "-p")
  -s, --script PATH        Script to run (default: ./git_file_rename.sh)
  --clean                  Clean work directory and exit
  -h, --help               Show this help message

Examples:
  # Run with 4 parallel processes
  $0 -j 4

  # Dry run with 8 parallel processes
  $0 -j 8 -a "-d"

  # Custom repos per batch
  $0 -j 4 -n 10

  # Use custom repo list
  $0 -r my_repos.txt -j 6

Environment Variables:
  MAX_PARALLEL     Number of parallel processes
  SCRIPT_ARGS      Arguments to pass to script
  REPOS_PER_BATCH  Repositories per batch

Performance Tips:
  - CPU cores - 1 is often optimal: -j \$(($(nproc) - 1))
  - For network-bound ops, try -j 8 or higher
  - Adjust batch size with -n if batches are uneven
  - Monitor with 'htop' to check CPU/network usage

HELP
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header "Parallel Git File Rename Runner"
    
    echo "Configuration:"
    echo "  Script: $SCRIPT"
    echo "  Script args: $SCRIPT_ARGS"
    echo "  Repo list: $REPO_LIST_FILE"
    echo "  Max parallel: $MAX_PARALLEL"
    echo "  Work directory: $WORK_DIR"
    echo ""
    
    # Validate
    validate_setup
    
    # Setup
    cleanup_previous_run
    local total_repos=$(setup_work_directory)
    local batch_count=$(split_repositories "$total_repos")
    
    echo ""
    
    # Run
    run_parallel "$batch_count"
    
    # Post-process
    show_batch_results
    
    echo ""
    print_success "Parallel execution completed!"
    print_info "Review results in: $WORK_DIR/"
}

# Run main
main "$@"
