# Changes Summary

This document summarizes the changes made to make Shannon and PentestGPT work correctly with the Juice Shop example.

## What Was Fixed

### 1. Fixed Shannon Configuration File (`juice-shop.yaml`)

**Problem:** The original configuration had incorrect field names that didn't match Shannon's expected schema.

**Changes:**
- Changed `type: path` to `type: url_path` for URL-based rules
- Changed `url_path: "value"` field name to `value: "value"`
- Fixed method-based rules to use `value` instead of `url_path`
- Removed `pipeline` section that was non-standard

**Example:**
```yaml
# Before (incorrect):
- description: "Login endpoint"
  type: path
  url_path: "/rest/user/login"

# After (correct):
- description: "Login endpoint"
  type: url_path
  value: "/rest/user/login"
```

### 2. Created Docker Configuration Files

**Added Files:**
- `workshop-bundle/dockerfiles/shannon.Dockerfile` - Dockerfile for Shannon AI pentester
- `workshop-bundle/dockerfiles/pentestgpt.Dockerfile` - Dockerfile for PentestGPT

These Dockerfiles are copied to the respective tool directories during setup.

### 3. Created Automation Scripts

**Added Scripts:**

#### `workshop-bundle/setup.sh`
Automated setup script that:
- Creates the tools directory structure
- Clones Shannon and PentestGPT repositories
- Copies Dockerfiles to the correct locations
- Sets up Shannon configuration
- Clones Juice Shop source code
- Configures git settings for the workspace
- Creates output directories

#### `workshop-bundle/verify-setup.sh`
Verification script that checks:
- Environment file exists and API key is configured
- Tool repositories are cloned
- Dockerfiles are in place
- Configuration files exist
- Workspace is properly set up
- Docker services are running (if applicable)

#### `workshop-bundle/reset-workspace.sh`
Cleanup script that:
- Removes Shannon's `.shannon` directory with old findings
- Cleans untracked files from the workspace
- Resets modified files to their original state
- Prevents Shannon from ingesting stale data from previous runs

### 4. Updated README.md

**Improvements:**
- Added Quick Reference section at the top for fast access to common commands
- Added automated setup instructions using `setup.sh`
- Kept manual setup instructions for those who want detailed understanding
- Added references to the new helper scripts
- Simplified configuration instructions
- Added verification step

## How to Use

### First Time Setup (Automated - Recommended)

```bash
cd sans-offensive-ai-in-practice-nov-2026/workshop-bundle
./setup.sh
# Edit .env and add your ANTHROPIC_API_KEY
docker compose up -d
./verify-setup.sh
```

### Running Shannon

```bash
docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \
  http://juice-shop:3000 \
  /app/repos/juice-shop \
  --task-queue shannon \
  --config /app/configs/juice-shop.yaml
```

### Resetting Between Shannon Runs

```bash
./reset-workspace.sh
```

### Running PentestGPT

```bash
docker compose exec -it pentestgpt bash
pentestgpt --target juice-shop:3000
```

## Files Modified

1. `/juice-shop.yaml` - Fixed configuration schema
2. `/README.md` - Added quick start and automation documentation

## Files Added

1. `/workshop-bundle/dockerfiles/shannon.Dockerfile` - Shannon Docker configuration
2. `/workshop-bundle/dockerfiles/pentestgpt.Dockerfile` - PentestGPT Docker configuration
3. `/workshop-bundle/setup.sh` - Automated setup script
4. `/workshop-bundle/verify-setup.sh` - Setup verification script
5. `/workshop-bundle/reset-workspace.sh` - Workspace cleanup script
6. `/.gitignore` - Git ignore rules for sensitive files and outputs
7. `/CHANGES.md` - This file

## Key Benefits

1. **Automated Setup:** One command (`./setup.sh`) sets up the entire environment
2. **Correct Configuration:** Fixed Shannon config ensures proper operation
3. **Easy Verification:** `./verify-setup.sh` confirms everything is ready
4. **Clean Resets:** `./reset-workspace.sh` ensures fresh Shannon scans
5. **Better Documentation:** Quick reference and clear instructions reduce setup time
6. **Safe Repository:** `.gitignore` prevents accidentally committing API keys, cloned tools, and scan outputs

## Technical Details

### Shannon Configuration Schema

Shannon expects configuration rules in this format:
```yaml
rules:
  focus:
    - description: "Description of what to focus on"
      type: url_path         # or 'method' for HTTP methods
      value: "/path/to/test" # the actual value to match
```

The original file used `type: path` with `url_path: "value"` which didn't match Shannon's parser expectations.

### Docker Setup

Both tools now have proper Dockerfiles that:
- Install required system dependencies
- Set up the correct runtime environment
- Configure necessary environment variables
- Work seamlessly with the docker-compose.yml configuration

### Workspace Management

Shannon analyzes source code in the workspace and writes findings there. Proper git configuration and cleanup between runs prevents:
- Stale findings from being re-ingested
- Analysis degradation
- Incorrect results from cached data
