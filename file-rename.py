#!/usr/bin/env python3
"""
Git File Rename - Python Version

Clones repositories and creates renamed copies of files based on string
substitution patterns. Also supports fix mode for updating existing files.
"""

import os
import sys
import subprocess
import argparse
import shutil
import re
import time
from pathlib import Path
from typing import List, Tuple, Dict, Optional


class GitFileRename:
    def __init__(self, config_vars: Dict[str, str]):
        """Initialize with configuration variables from config.sh"""
        self.config = config_vars
        self.base_dir = Path.cwd()
        
        # Parse configuration
        self.repo_list_file = config_vars.get('REPO_LIST_FILE', 'repos.txt')
        self.git_base_url = config_vars.get('GIT_BASE_URL', '')
        self.git_auth_method = config_vars.get('GIT_AUTH_METHOD', 'none')
        self.git_username = config_vars.get('GIT_USERNAME', '')
        self.git_auth_token = config_vars.get('GIT_AUTH_TOKEN', '')
        self.base_branch = config_vars.get('BASE_BRANCH', '')
        self.branch_name = config_vars.get('BRANCH_NAME', '')
        self.auto_create_branch = config_vars.get('AUTO_CREATE_BRANCH', 'true').lower() == 'true'
        self.case_sensitive = config_vars.get('CASE_SENSITIVE', 'true').lower() == 'true'
        self.work_dir = Path(config_vars.get('WORK_DIR', './repos_temp'))
        self.commit_message = config_vars.get('COMMIT_MESSAGE', 'Update string replacements across repository')
        self.log_file = Path(config_vars.get('LOG_FILE', './batch_update_log.txt'))
        self.fix_mode = config_vars.get('FIX_MODE', 'false').lower() == 'true'
        
        # Parse replacements
        self.replacements = self._parse_replacements(config_vars.get('REPLACEMENTS', ''))
        
        # Colors
        self.RED = '\033[0;31m'
        self.GREEN = '\033[0;32m'
        self.YELLOW = '\033[1;33m'
        self.BLUE = '\033[0;34m'
        self.CYAN = '\033[0;36m'
        self.NC = '\033[0m'
        
    def _parse_replacements(self, replacements_str: str) -> List[Tuple[str, str]]:
        """Parse REPLACEMENTS array from config"""
        # Extract array elements from bash array syntax
        # Example: ( "dev|prod" "test|final" )
        pattern = r'"([^"]+)"'
        matches = re.findall(pattern, replacements_str)
        
        result = []
        for match in matches:
            if '|' in match:
                old, new = match.split('|', 1)
                result.append((old.strip(), new.strip()))
        
        return result
    
    def print_header(self, text: str):
        """Print a header"""
        print(f"{self.BLUE}{'='*70}{self.NC}")
        print(f"{self.BLUE}{text}{self.NC}")
        print(f"{self.BLUE}{'='*70}{self.NC}")
    
    def print_success(self, text: str):
        """Print success message"""
        print(f"{self.GREEN}✓ {text}{self.NC}")
    
    def print_error(self, text: str):
        """Print error message"""
        print(f"{self.RED}✗ {text}{self.NC}")
    
    def print_warning(self, text: str):
        """Print warning message"""
        print(f"{self.YELLOW}⚠ {text}{self.NC}")
    
    def print_info(self, text: str):
        """Print info message"""
        print(f"{self.CYAN}ℹ {text}{self.NC}")
    
    def log_to_file(self, message: str):
        """Log message to file"""
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(self.log_file, 'a') as f:
            f.write(f"[{timestamp}] {message}\n")
    
    def run_command(self, cmd: List[str], cwd: Optional[Path] = None, 
                   check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
        """Execute a shell command"""
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd,
                capture_output=capture_output,
                text=True,
                check=check
            )
            return result
        except subprocess.CalledProcessError as e:
            if capture_output:
                self.print_error(f"Command failed: {' '.join(cmd)}")
                if e.stderr:
                    print(e.stderr)
            if check:
                raise
            return e
    
    def construct_repo_url(self, repo_input: str) -> str:
        """Construct full repository URL"""
        # If already a full URL, return as-is
        if repo_input.startswith('http://') or repo_input.startswith('https://') or repo_input.startswith('git@'):
            return repo_input
        
        # Remove trailing .git if present
        repo_name = repo_input.rstrip('.git')
        
        # Construct URL based on auth method
        if self.git_auth_method == 'token':
            base_url = self.git_base_url.replace('https://', '')
            return f"https://{self.git_username}:{self.git_auth_token}@{base_url}/{repo_name}.git"
        elif self.git_auth_method == 'ssh':
            if 'github.com' in self.git_base_url:
                org = self.git_base_url.split('/')[-1]
                return f"git@github.com:{org}/{repo_name}.git"
            else:
                return f"{self.git_base_url}/{repo_name}.git"
        else:
            return f"{self.git_base_url}/{repo_name}.git"
    
    def get_repo_name(self, repo_input: str) -> str:
        """Extract repository name directly from input"""
        # If it's a URL, extract the name
        if repo_input.startswith('http://') or repo_input.startswith('https://') or repo_input.startswith('git@'):
            name = repo_input.rstrip('/').split('/')[-1]
            if name.endswith('.git'):
                name = name[:-4]
            return name
        # Otherwise use the input directly as the name
        return repo_input.rstrip('.git')
    
    def clone_repository(self, url: str, target_dir: Path, repo_name: str) -> bool:
        """Clone a git repository if it doesn't exist"""
        max_retries = 3
        
        if target_dir.exists():
            self.log_to_file(f"Repository: {repo_name} | Status: EXISTS | Details: Using existing clone")
            return True
        
        self.print_info(f"Cloning repository: {repo_name}")
        
        for retry in range(max_retries):
            try:
                self.run_command(['git', 'clone', url, str(target_dir)], capture_output=True)
                self.print_success(f"Successfully cloned to: {target_dir}")
                self.log_to_file(f"Repository: {repo_name} | Status: CLONED | Details: New clone")
                return True
            except subprocess.CalledProcessError as e:
                if retry < max_retries - 1:
                    self.print_warning(f"Clone failed (attempt {retry + 1}/{max_retries}), retrying in 5 seconds...")
                    time.sleep(5)
                else:
                    self.print_error(f"Failed to clone repository after {max_retries} attempts: {url}")
                    if e.stderr:
                        print(e.stderr)
                    self.log_to_file(f"Repository: {repo_name} | Status: FAILED | Details: Clone failed after {max_retries} attempts")
                    return False
        
        return False
    
    def checkout_base_branch(self, repo_dir: Path, base_branch: str) -> bool:
        """Checkout base branch and pull if no local commits ahead"""
        if not base_branch:
            return True
        
        try:
            # Get current branch
            result = self.run_command(['git', 'branch', '--show-current'], cwd=repo_dir)
            current_branch = result.stdout.strip()
            
            # Checkout if needed
            if current_branch != base_branch:
                self.print_info(f"Checking out base branch: {base_branch}")
                try:
                    self.run_command(['git', 'checkout', base_branch], cwd=repo_dir, capture_output=True)
                    self.print_success(f"Checked out base branch: {base_branch}")
                except subprocess.CalledProcessError:
                    # Try fetching
                    self.print_info("Branch not found locally, trying to fetch from remote...")
                    self.run_command(['git', 'fetch', 'origin', f"{base_branch}:{base_branch}"], cwd=repo_dir, capture_output=True)
                    self.run_command(['git', 'checkout', base_branch], cwd=repo_dir, capture_output=True)
                    self.print_success(f"Fetched and checked out base branch: {base_branch}")
            else:
                self.print_info(f"Already on base branch: {base_branch}")
            
            # Fetch and pull if no local commits ahead
            self.run_command(['git', 'fetch', 'origin', base_branch], cwd=repo_dir, capture_output=True)
            
            # Check commits ahead
            result = self.run_command(
                ['git', 'rev-list', '--count', f'origin/{base_branch}..HEAD'],
                cwd=repo_dir,
                check=False
            )
            commits_ahead = int(result.stdout.strip() or '0')
            
            if commits_ahead == 0:
                self.print_info(f"Pulling latest changes from origin/{base_branch}...")
                self.run_command(['git', 'pull', 'origin', base_branch], cwd=repo_dir, capture_output=True)
                self.print_success("Successfully pulled latest changes")
            else:
                self.print_info(f"Local branch has {commits_ahead} commit(s) ahead of remote - skipping pull")
            
            return True
        except subprocess.CalledProcessError:
            self.print_error(f"Failed to checkout base branch: {base_branch}")
            return False
    
    def create_or_checkout_branch(self, repo_dir: Path, branch_name: str) -> bool:
        """Create or checkout working branch"""
        if not branch_name:
            return True
        
        try:
            # Check if branch exists
            result = self.run_command(
                ['git', 'show-ref', '--verify', f'refs/heads/{branch_name}'],
                cwd=repo_dir,
                check=False,
                capture_output=True
            )
            
            if result.returncode == 0:
                # Branch exists, check it out
                self.print_info(f"Checking out existing branch: {branch_name}")
                self.run_command(['git', 'checkout', branch_name], cwd=repo_dir, capture_output=True)
                
                # Pull if no commits ahead
                self.run_command(['git', 'fetch', 'origin', branch_name], cwd=repo_dir, capture_output=True, check=False)
                result = self.run_command(
                    ['git', 'rev-list', '--count', f'origin/{branch_name}..HEAD'],
                    cwd=repo_dir,
                    check=False
                )
                commits_ahead = int(result.stdout.strip() or '0')
                
                if commits_ahead == 0:
                    self.print_info(f"Pulling latest changes from origin/{branch_name}...")
                    self.run_command(['git', 'pull', 'origin', branch_name], cwd=repo_dir, capture_output=True, check=False)
                    self.print_success("Successfully pulled latest changes")
                else:
                    self.print_info(f"Local branch has {commits_ahead} commit(s) ahead of remote - skipping pull")
            else:
                # Branch doesn't exist
                if self.auto_create_branch:
                    self.print_info(f"Creating new branch: {branch_name}")
                    self.run_command(['git', 'checkout', '-b', branch_name], cwd=repo_dir, capture_output=True)
                else:
                    self.print_warning(f"Branch {branch_name} does not exist and AUTO_CREATE_BRANCH is false")
                    return False
            
            return True
        except subprocess.CalledProcessError:
            return False
    
    def find_items_with_pattern(self, repo_dir: Path, pattern: str) -> List[Path]:
        """Find files and directories matching pattern"""
        matching_items = []
        
        for item in repo_dir.rglob('*'):
            # Skip .git directory
            if '.git' in item.parts:
                continue
            
            item_name = item.name
            
            # Check pattern match based on case sensitivity
            if self.case_sensitive:
                if pattern in item_name:
                    matching_items.append(item)
            else:
                if pattern.lower() in item_name.lower():
                    matching_items.append(item)
        
        return matching_items
    
    def replace_content_in_file(self, file_path: Path, old_str: str, new_str: str, verbose: bool = True) -> bool:
        """Replace content in a single file"""
        try:
            # Check if it's a text file
            result = self.run_command(['file', str(file_path)], capture_output=True, check=False)
            if 'text' not in result.stdout.lower():
                return False
            
            # Read file
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Check if old string is present
            if self.case_sensitive:
                if old_str not in content:
                    return False
                new_content = content.replace(old_str, new_str)
            else:
                # Case-insensitive replacement
                pattern = re.compile(re.escape(old_str), re.IGNORECASE)
                if not pattern.search(content):
                    return False
                new_content = pattern.sub(new_str, content)
            
            # Write back
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            if verbose:
                print(f"      → Replaced content in: {file_path.name}")
            
            return True
        except Exception as e:
            return False
    
    def replace_content_in_directory(self, dir_path: Path, old_str: str, new_str: str) -> int:
        """Replace content in all files in directory"""
        count = 0
        for file_path in dir_path.rglob('*'):
            if file_path.is_file() and '.git' not in file_path.parts:
                if self.replace_content_in_file(file_path, old_str, new_str, verbose=False):
                    count += 1
        return count
    
    def create_renamed_copy(self, original_item: Path, old_str: str, new_str: str, dry_run: bool) -> bool:
        """Create a renamed copy of file or directory"""
        item_name = original_item.name
        
        # Perform replacement
        if self.case_sensitive:
            new_name = item_name.replace(old_str, new_str)
        else:
            pattern = re.compile(re.escape(old_str), re.IGNORECASE)
            new_name = pattern.sub(new_str, item_name)
        
        # Skip if name unchanged
        if new_name == item_name:
            return False
        
        new_item = original_item.parent / new_name
        
        # Check if target exists
        if new_item.exists():
            print(f"    {self.YELLOW}⚠ Target already exists: {new_name}{self.NC}")
            return False
        
        if dry_run:
            if original_item.is_dir():
                print(f"    [DRY RUN] Would copy directory to: {new_name}/")
                print(f"    [DRY RUN] Would replace '{old_str}' → '{new_str}' in all files")
            else:
                print(f"    [DRY RUN] Would copy file to: {new_name}")
                print(f"    [DRY RUN] Would replace '{old_str}' → '{new_str}' in file contents")
            return True
        
        # Copy item
        if original_item.is_dir():
            shutil.copytree(original_item, new_item)
            self.print_success(f"Created directory: {new_name}/")
            # Replace content in all files
            self.replace_content_in_directory(new_item, old_str, new_str)
        else:
            shutil.copy2(original_item, new_item)
            self.print_success(f"Created file: {new_name}")
            # Replace content in file
            self.replace_content_in_file(new_item, old_str, new_str)
        
        return True
    
    def process_repository(self, repo_input: str, dry_run: bool, push: bool) -> int:
        """Process a repository in normal mode"""
        repo_url = self.construct_repo_url(repo_input)
        repo_name = self.get_repo_name(repo_input)  # Use input directly
        repo_dir = self.work_dir / repo_name
        
        self.print_header(f"Processing repository: {repo_name}")
        
        # Clone
        if not self.clone_repository(repo_url, repo_dir, repo_name):
            return 0
        
        # Checkout base branch
        if self.base_branch:
            self.checkout_base_branch(repo_dir, self.base_branch)
        
        # Create/checkout working branch
        if self.branch_name:
            self.create_or_checkout_branch(repo_dir, self.branch_name)
        
        items_copied = 0
        
        # Process each replacement
        for old_str, new_str in self.replacements:
            print()
            self.print_info(f"Searching for files/directories containing '{old_str}' in name...")
            
            matching_items = self.find_items_with_pattern(repo_dir, old_str)
            
            if not matching_items:
                print(f"  No files or directories found with '{old_str}' in name")
                continue
            
            print(f"  Found {len(matching_items)} item(s)")
            
            for item in matching_items:
                rel_path = item.relative_to(repo_dir)
                
                if item.is_dir():
                    print(f"  Processing directory: {rel_path}/")
                else:
                    print(f"  Processing file: {rel_path}")
                
                if self.create_renamed_copy(item, old_str, new_str, dry_run):
                    items_copied += 1
        
        print()
        print(f"Items copied in {repo_name}: {items_copied}")
        
        # Git operations immediately after processing
        if push and not dry_run and items_copied > 0:
            print()
            self.print_header(f"Git Push Operations for {repo_name}")
            self.git_add_commit_push(repo_dir, self.commit_message, repo_name)
        
        return items_copied
    
    def process_repository_fix_mode(self, repo_input: str, dry_run: bool, push: bool) -> int:
        """Process a repository in fix mode"""
        repo_url = self.construct_repo_url(repo_input)
        repo_name = self.get_repo_name(repo_input)  # Use input directly
        repo_dir = self.work_dir / repo_name
        
        self.print_header(f"Processing repository (FIX MODE): {repo_name}")
        
        # Clone
        if not self.clone_repository(repo_url, repo_dir, repo_name):
            return 0
        
        # Checkout base branch
        if self.base_branch:
            self.checkout_base_branch(repo_dir, self.base_branch)
        
        # Create/checkout working branch
        if self.branch_name:
            self.create_or_checkout_branch(repo_dir, self.branch_name)
        
        items_fixed = 0
        
        # Process each replacement - search for NEW pattern
        for old_str, new_str in self.replacements:
            print()
            self.print_info(f"Searching for files/directories containing '{new_str}' in name (to fix content)...")
            
            matching_items = self.find_items_with_pattern(repo_dir, new_str)
            
            if not matching_items:
                print(f"  No files or directories found with '{new_str}' in name")
                continue
            
            print(f"  Found {len(matching_items)} item(s) to check for content replacement")
            
            for item in matching_items:
                rel_path = item.relative_to(repo_dir)
                
                if item.is_dir():
                    print(f"  Checking directory: {rel_path}/")
                    
                    if dry_run:
                        print(f"    [DRY RUN] Would replace '{old_str}' → '{new_str}' in all files")
                        items_fixed += 1
                    else:
                        count = self.replace_content_in_directory(item, old_str, new_str)
                        if count > 0:
                            self.print_success(f"Fixed content in {count} file(s) in directory")
                            items_fixed += 1
                        else:
                            print("    No changes needed in directory")
                else:
                    print(f"  Checking file: {rel_path}")
                    
                    if dry_run:
                        try:
                            with open(item, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()
                                if old_str in content:
                                    print(f"    [DRY RUN] Would replace '{old_str}' → '{new_str}' in file")
                                    items_fixed += 1
                                else:
                                    print("    No changes needed")
                        except:
                            print("    No changes needed")
                    else:
                        if self.replace_content_in_file(item, old_str, new_str):
                            items_fixed += 1
                        else:
                            print("    No changes needed")
        
        print()
        print(f"Items fixed in {repo_name}: {items_fixed}")
        
        # Git operations immediately after processing
        if push and not dry_run and items_fixed > 0:
            print()
            self.print_header(f"Git Push Operations for {repo_name}")
            self.git_add_commit_push(repo_dir, self.commit_message, repo_name)
        
        return items_fixed
    
    def git_add_commit_push(self, repo_dir: Path, commit_message: str, repo_name: str) -> bool:
        """Add, commit, and push changes"""
        max_retries = 3
        
        try:
            # Check if there are changes
            result = self.run_command(['git', 'status', '--porcelain'], cwd=repo_dir)
            if not result.stdout.strip():
                self.print_info("No changes to commit")
                return True
            
            self.print_info(f"Git operations in: {repo_name}")
            
            # Add changes
            print("  Adding changes...")
            self.run_command(['git', 'add', '-A'], cwd=repo_dir, capture_output=True)
            
            # Commit
            print(f"  Committing with message: '{commit_message}'")
            self.run_command(['git', 'commit', '-m', commit_message], cwd=repo_dir, capture_output=True)
            
            # Get current branch
            result = self.run_command(['git', 'branch', '--show-current'], cwd=repo_dir)
            branch = result.stdout.strip()
            
            # Push with retry
            print(f"  Pushing to branch: {branch}")
            for retry in range(max_retries):
                try:
                    self.run_command(['git', 'push', 'origin', branch], cwd=repo_dir, capture_output=True)
                    self.print_success("Successfully pushed changes")
                    self.log_to_file(f"Repository: {repo_name} | Status: PUSHED | Details: Branch: {branch}")
                    return True
                except subprocess.CalledProcessError as e:
                    if retry < max_retries - 1:
                        self.print_warning(f"Push failed (attempt {retry + 1}/{max_retries}), retrying in 5 seconds...")
                        time.sleep(5)
                    else:
                        self.print_error(f"Failed to push changes after {max_retries} attempts")
                        if e.stderr:
                            print(e.stderr)
                        self.log_to_file(f"Repository: {repo_name} | Status: PUSH_FAILED | Details: Branch: {branch}")
                        return False
            
            return False
        except subprocess.CalledProcessError as e:
            self.print_error("Git operation failed")
            if e.stderr:
                print(e.stderr)
            return False
    
    def run(self, dry_run: bool = False, push: bool = False, commit_message: Optional[str] = None, fix_mode: Optional[bool] = None):
        """Main execution"""
        # Override config with command line args
        if fix_mode is not None:
            self.fix_mode = fix_mode
        
        if commit_message:
            self.commit_message = commit_message
        
        self.print_header("Git File Rename - Starting")
        
        if self.fix_mode:
            print("MODE: Fix existing files (content replacement only)")
        else:
            print("MODE: Copy and rename files/directories")
        
        print(f"Repository list: {self.repo_list_file}")
        print(f"Working directory: {self.work_dir}")
        print(f"Log file: {self.log_file}")
        print()
        
        # Initialize log
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        self.log_to_file("=== Git File Rename Script Started (Python) ===")
        self.log_to_file(f"Mode: {'Fix content only' if self.fix_mode else 'Copy and rename'}")
        
        # Validate
        if not Path(self.repo_list_file).exists():
            self.print_error(f"Repository list file not found: {self.repo_list_file}")
            return 1
        
        if not self.replacements:
            self.print_error("No replacements defined")
            return 1
        
        print()
        self.print_info(f"Replacements: {len(self.replacements)}")
        self.print_info(f"Case sensitive: {self.case_sensitive}")
        self.print_info(f"Base branch: {self.base_branch or 'current'}")
        self.print_info(f"Working branch: {self.branch_name or 'current'}")
        
        print()
        print("Replacement mappings:")
        for old_str, new_str in self.replacements:
            print(f"  '{old_str}' → '{new_str}'")
        
        # Create work dir
        self.work_dir.mkdir(parents=True, exist_ok=True)
        
        # Process repositories
        total_items = 0
        successful_repos = 0
        total_repos = 0
        
        with open(self.repo_list_file, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                
                total_repos += 1
                print()
                
                if self.fix_mode:
                    items = self.process_repository_fix_mode(line, dry_run, push)
                else:
                    items = self.process_repository(line, dry_run, push)
                
                if items >= 0:
                    successful_repos += 1
                    total_items += items
        
        # Summary
        print()
        self.print_header("Summary")
        
        print(f"Total items {'fixed' if self.fix_mode else 'copied'}: {total_items}")
        print(f"Successful repositories: {successful_repos}/{total_repos}")
        print(f"Log file: {self.log_file}")
        
        if dry_run:
            print()
            self.print_warning("[DRY RUN MODE] No files were actually copied or committed")
        
        self.log_to_file("=== Script Completed ===")
        self.log_to_file(f"Total items: {total_items}")
        self.log_to_file(f"Successful repos: {successful_repos}/{total_repos}")
        
        print()
        if successful_repos == total_repos:
            self.print_success("Operation completed successfully!")
            return 0
        else:
            self.print_warning("Operation completed with some errors")
            return 1


def parse_bash_config(config_file: str) -> Dict[str, str]:
    """Parse bash config file and extract variables"""
    config = {}
    
    try:
        with open(config_file, 'r') as f:
            content = f.read()
        
        # Extract simple variable assignments
        var_pattern = r'^([A-Z_]+)=(["\']?)(.+?)\2\s*$'
        for line in content.split('\n'):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            match = re.match(var_pattern, line)
            if match:
                var_name, _, var_value = match.groups()
                
                # Handle environment variable substitutions
                var_value = re.sub(r'\$\{([^}]+):-([^}]*)\}', r'\2', var_value)
                var_value = re.sub(r'\$\{([^}]+)\}', '', var_value)
                
                config[var_name] = var_value
        
        # Extract REPLACEMENTS array
        replacements_pattern = r'declare -a REPLACEMENTS=\((.*?)\)'
        match = re.search(replacements_pattern, content, re.DOTALL)
        if match:
            config['REPLACEMENTS'] = match.group(1)
    
    except Exception as e:
        print(f"Error parsing config file: {e}")
        sys.exit(1)
    
    return config


def main():
    parser = argparse.ArgumentParser(
        description='Git File Rename - Python Version',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                           # Run with default config.sh
  %(prog)s -c my-config.sh          # Use custom config file
  %(prog)s -d                        # Dry run (don't copy files)
  %(prog)s -p -m "Add new files"    # Copy files and push to git
  %(prog)s --fix-content             # Fix mode: update existing files
        """
    )
    parser.add_argument(
        '-c', '--config',
        default='config.sh',
        help='Path to config file (default: config.sh)'
    )
    parser.add_argument(
        '-m', '--message',
        help='Commit message (only used with --push)'
    )
    parser.add_argument(
        '-d', '--dry-run',
        action='store_true',
        help='Perform dry run (no file copying or git operations)'
    )
    parser.add_argument(
        '-p', '--push',
        action='store_true',
        help='Commit and push changes to git after copying files'
    )
    parser.add_argument(
        '-f', '--fix-content', '--fix',
        action='store_true',
        dest='fix_mode',
        help='Fix mode: only update content in existing files (no copying)'
    )
    
    args = parser.parse_args()
    
    # Parse config file
    config_vars = parse_bash_config(args.config)
    
    # Create instance and run
    renamer = GitFileRename(config_vars)
    exit_code = renamer.run(
        dry_run=args.dry_run,
        push=args.push,
        commit_message=args.message,
        fix_mode=args.fix_mode
    )
    sys.exit(exit_code)


if __name__ == '__main__':
    main()
