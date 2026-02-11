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
  - batch_XXX_output.txt  (detailed output per batch)
  - batch_XXX.log         (git operations log per batch)
  - combined.log          (all logs combined)

✓ Parallel execution completed!
```

### Work Directory Structure

```
parallel_work/
├── repos_clean.txt          # Cleaned repository list
├── batch_000                # First batch of repos
├── batch_000_output.txt     # Detailed output for batch 0
├── batch_000.log           # Git operations log for batch 0
├── batch_000_status.txt    # SUCCESS or FAILED
├── batch_001                # Second batch
├── batch_001_output.txt
├── batch_001.log
├── batch_001_status.txt
├── ...
├── combined.log            # All logs combined
└── repos_batch_000/        # Cloned repos for batch 0
    ├── repo1/
    ├── repo2/
    └── ...
```

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
   cat parallel_work/combined.log | grep -i error
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
