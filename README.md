# SANS: Workshop: Offensive AI in Practice - Hands on Exploitation of Vulnerable Applications Using Open Source Pentest Tool
## November 2026

---

## 🚀 Quick Reference

**First time setup:**
```bash
cd sans-offensive-ai-in-practice-nov-2026/workshop-bundle
./setup.sh                    # Run automated setup
# Edit .env and add your ANTHROPIC_API_KEY
docker compose up -d          # Start all services
./verify-setup.sh             # Verify everything is working
```

**Run tools:**
```bash
# ZAP baseline scan (~5 minutes)
docker compose run --rm zap-baseline

# Shannon pentest (check README for full command)
docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \
  http://juice-shop:3000 /app/repos/juice-shop \
  --task-queue shannon --config /app/configs/juice-shop.yaml

# PentestGPT interactive session
docker compose exec -it pentestgpt bash
pentestgpt --target juice-shop:3000
```

**Monitor:**
- Juice Shop: http://localhost:3000
- Temporal UI: http://localhost:8233
- Reports: `workshop-bundle/out/` and `workshop-bundle/workspace/juice-shop/.shannon/deliverables/`

---

## Directory Map

After setup is complete, your project should look like this:

```
sans-ai-workshop-nov-2026/
├── README.md                          <-- You are here
└── workshop-bundle/
    ├── .env                           <-- Your API keys (copy from .env.example)
    ├── .env.example
    ├── docker-compose.yml             <-- Defines all services (run from here)
    │
    ├── tools/                         <-- Cloned tool repositories go here
    │   ├── shannon/                   <-- git clone https://github.com/KeygraphHQ/shannon
    │   │   ├── Dockerfile             <-- Must exist (used by docker compose build)
    │   │   ├── apps/                  <-- Shannon source code
    │   │   ├── configs/               <-- Pentest config files (e.g., juice-shop.yaml)
    │   │   └── ...
    │   └── PentestGPT/                <-- git clone https://github.com/greydgl/pentestgpt (pinned to b986930)
    │       ├── Dockerfile             <-- Must exist (used by docker compose build)
    │       └── ...
    │
    ├── workspace/                     <-- Shared working directory (mounted into containers)
    │   └── juice-shop/                <-- Target repo for Shannon findings
    │       └── .shannon/deliverables/ <-- Security reports land here
    │
    └── out/                           <-- Tool output / reports
        ├── zap/                       <-- ZAP scan reports (e.g., zap_baseline_report.html)
        └── shannon/                   <-- Shannon audit logs and session data
```

### Key Points

- **All `docker compose` commands must be run from `workshop-bundle/`** -- that's where `docker-compose.yml` lives.
- The `tools/` directory must contain **full git clones** of Shannon and PentestGPT (not just empty folders). Docker Compose needs each repo's `Dockerfile` to build the worker containers.
- The `workspace/` directory is mounted into both Shannon and PentestGPT containers, so findings persist on your host machine.
- The `out/` directory collects reports from ZAP and Shannon.

---

## Prerequisites

- Clone this repository
```bash
git clone git@github.com:rpigu-i/sans-offensive-ai-in-practice-nov-2026.git
```
- Install Docker and Docker Compose. This can be found at: https://www.docker.com/products/docker-desktop/
- Anthropic API key available from: https://platform.claude.com/

---

## Quick Start (Automated Setup)

We've provided a setup script that automates the entire installation process:

```bash
cd sans-offensive-ai-in-practice-nov-2026/workshop-bundle
./setup.sh
```

The setup script will:
1. Create the tools directory structure
2. Clone Shannon and PentestGPT repositories (PentestGPT is pinned to commit `b986930`, the last version with the `pentestgpt` command)
3. Copy the fallback Dockerfiles only if a repo doesn't ship its own (both currently do)
4. Set up the Shannon configuration
5. Clone the Juice Shop source code for analysis
6. Create workspace and output directories

After running the setup script:
1. Edit `.env` and add your ANTHROPIC_API_KEY
2. Start all services: `docker compose up -d`
3. Wait for services to be healthy: `docker compose ps`
4. Verify setup: `./verify-setup.sh`
5. Follow the instructions below to run ZAP, Shannon, or PentestGPT

**Note:** The repository includes a `.gitignore` file that prevents accidentally committing:
- API keys (`.env` files)
- Cloned tool repositories (`tools/`)
- Workspace files (`workspace/`)
- Scan outputs and reports (`out/`)

---

## Manual Setup (Alternative)

If you prefer to set up manually or want to understand each step:

### 1. Set up your API key
```bash
cd workshop-bundle
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY
```

### 2. Clone the tools

```bash
# From within /sans-offensive-ai-in-practice-nov-2026/workshop-bundle
mkdir -p tools
git clone https://github.com/KeygraphHQ/shannon tools/shannon
git clone https://github.com/greydgl/pentestgpt tools/PentestGPT
# Upstream removed the `pentestgpt` command on 2026-07-13; pin to the last version that has it
git -C tools/PentestGPT checkout b986930
```

### 3. Check the Dockerfiles

Both Shannon and PentestGPT ship their own `Dockerfile`, and Docker Compose builds from those. **Don't overwrite them** with the files in `dockerfiles/`; those are outdated fallbacks that no longer build against current upstream code.

### 4. Set up Shannon configuration

The Shannon configuration file is already included in the repository at the root as `juice-shop.yaml`. The setup script copies it to the correct location, or you can do it manually:

```bash
mkdir -p tools/shannon/configs
cp ../juice-shop.yaml tools/shannon/configs/juice-shop.yaml
```

This configuration pre-authenticates Shannon, focuses it on the highest-value attack surface, and excludes noise endpoints to keep the scan within the workshop time window. See `juice-shop.yaml` in the repository root for the full configuration.

### 5. Clone Juice Shop source for Shannon analysis

```bash
# From inside workshop-bundle/
git clone https://github.com/juice-shop/juice-shop.git workspace/juice-shop
cd workspace/juice-shop
git config user.email "pentest@localhost"
git config user.name "Pentest Agent"
cd ../..
```

### 6. Start all services

```bash
docker compose up -d
```

This will start:
- **Juice Shop** - http://localhost:3000 (vulnerable web app)
- **zap-baseline** - Zap tooling
- **pentestgpt** - PenTestGPT tooling
- **Shannon Temporal** - (you can validate via: `nc -vz localhost 7233`) (workflow engine)
- **Shannon Temporal UI** - http://localhost:8233 (monitoring dashboard)
- **Shannon Worker** is *not* started here. It's a one-shot job you launch with `docker compose run` (see Run Shannon below)
- **PostgreSQL** - Database for Temporal

---

## Run ZAP baseline (creates HTML report)

```bash
docker compose run --rm zap-baseline
# report at: ./out/zap/zap_baseline_report.html
```
This scan will take about five minutes to complete.
ZAP baseline scan scripts are included in the official ZAP images

---

## Run Shannon

Shannon is already included in `tools/shannon/`. Services should already be running from the Initial Setup step above.

### Verify Services are Running

Check that all services are healthy:
```bash
docker compose ps
```

You should see:
- `juice-shop` - STATUS: Up (healthy)
- `shannon-postgres` - STATUS: Up (healthy)
- `shannon-temporal` - STATUS: Up (healthy)
- `shannon-temporal-ui` - STATUS: Up

### Prepare a Target Repository

Shannon is a **white-box** pentester — it analyzes the target's source code to guide its exploitation strategy. Clone the actual Juice Shop source into your workspace so Shannon has something to analyze:

```bash
# From inside sans-offensive-ai-in-practice-nov-2026/workshop-bundle
rm -rf workspace/juice-shop
git clone https://github.com/juice-shop/juice-shop.git workspace/juice-shop
cd workspace/juice-shop
git config user.email "pentest@localhost"
git config user.name "Pentest Agent"
cd ../..
```

The `git config` lines set a local committer identity for this repo only — Shannon creates git checkpoints during its pre-recon phase, which requires a configured user even though nothing is pushed upstream.

> ⚠️ **Do not skip cloning the actual source.** Pointing Shannon at an empty repo causes its pre-recon agents to spin for hundreds of turns looking for code that isn't there, and can lead them to fall back on stale deliverables from previous runs — producing hallucinated findings instead of real ones.

### Start the Pentest

Run the pentest workflow from `workshop-bundle/`:

```bash
docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \
  http://juice-shop:3000 \
  /app/repos/juice-shop \
  --task-queue shannon \
  --config /app/configs/juice-shop.yaml
```

> ℹ️ **Path note:** `/app/repos/juice-shop` and `/app/configs/juice-shop.yaml` are paths **inside the worker container**, mapped from the host via volume mounts in `docker-compose.yml`:
>
> | Inside container | On host (relative to `workshop-bundle/`) |
> |---|---|
> | `/app/repos/juice-shop` | `./workspace/juice-shop` |
> | `/app/configs/juice-shop.yaml` | `./tools/shannon/configs/juice-shop.yaml` |

### Monitor Progress

**Temporal Web UI** (Recommended): http://localhost:8233
- View real-time workflow execution
- See activity history and task queues
- Monitor workflow state

**Worker Logs**:
```bash
docker compose logs -f shannon-worker
```

**Query Workflow Status**:
```bash
docker compose exec shannon-worker node apps/worker/dist/temporal/query.js <workflow-id>
```

### Results

Findings will be written to:
- `workshop-bundle/workspace/juice-shop/.shannon/deliverables` - Security findings and reports
- `out/shannon/` - Audit logs and session data (mounted at `/app/workspaces` in the worker)

The pentest runs through 5 phases:
1. **Pre-Recon** - External scans + code analysis
2. **Recon** - Attack surface mapping
3. **Vulnerability Analysis** - 5 parallel agents (injection, xss, auth, authz, ssrf)
4. **Exploitation** - Exploit confirmed vulnerabilities
5. **Reporting** - Executive security report

### Resetting the Workspace Between Runs

Shannon writes intermediate findings to `.shannon/deliverables/` inside the target repo. If you run Shannon a second time without clearing this state, the new run will ingest the previous run's output and its analysis will degrade.

**Easy way (using reset script):**
```bash
# From inside workshop-bundle/
./reset-workspace.sh
```

**Manual way:**
```bash
# From inside workshop-bundle/
cd workspace/juice-shop
rm -rf .shannon
git clean -fdx
git reset --hard
cd ../..
```

`git clean -fdx` removes untracked files and directories (including anything Shannon dropped outside `.shannon/`), and `git reset --hard` reverts any file modifications Shannon's exploit attempts may have made to tracked files.

---

## Run PentestGPT (Interactive)

PentestGPT is already included in `tools/PentestGPT/`. The container starts automatically with `docker compose up -d`.

### Connect to PentestGPT

Connect to the container interactively:

```bash
docker compose exec -it pentestgpt bash
```

You'll be in the `/workspace` directory where you can start pentesting.

### Run Against Juice Shop

Point it at Juice Shop:

```bash
pentestgpt --target juice-shop:3000
```

Or with specific instructions:

```bash
pentestgpt --target juice-shop:3000 --instruction "Focus on authentication bypass vulnerabilities"
```

### Common Options

```bash
pentestgpt --target juice-shop:3000              # Interactive TUI mode
pentestgpt --target juice-shop:3000 --mode pentest  # Breadth-first vuln identification (default mode is ctf)
pentestgpt --target juice-shop:3000 -v           # Verbose output
pentestgpt --list-sessions                       # List previous sessions
pentestgpt --resume --session-id <id>            # Resume a session
```

PentestGPT will guide you through an interactive penetration testing session with a TUI interface.

### If You Get "ENOENT: no such file or directory, uv_cwd" Error

If you encounter this error, the container needs to be recreated:

```bash
docker compose up -d pentestgpt
```

---

## Troubleshooting

### Shannon Scan Taking Too Long

Shannon scan durations can vary based on the target's attack surface and the AI agents' exploration paths. If scans consistently run long:

1. **Check for stale deliverables.** If you didn't reset the workspace between runs, Shannon may be ingesting old findings and looping. Run the reset commands in the "Resetting the Workspace Between Runs" section.

2. **Verify the config is loading.** Early in the worker log output, look for `Configuration file OK` with `configPath: '/app/configs/juice-shop.yaml'`. If this is missing, the `--config` flag isn't being picked up and the scan is running with no scope limits.

3. **Narrow the `focus` rules further.** Fewer focus paths in `juice-shop.yaml` produces fewer vulnerability hypotheses, which means less work in the exploit phase. Consider trimming to just `/rest/user/login` and `/api/Users` for the fastest possible demo.

### Shannon Temporal Not Starting

If you see "dependency failed to start: container shannon-temporal exited (1)", check the logs:

```bash
docker compose logs shannon-temporal
```

Common fixes:
- Ensure PostgreSQL is healthy: `docker compose ps shannon-postgres`
- Restart services: `docker compose restart shannon-temporal`

### Port Already in Use

If port 7233 or 8233 is already allocated:
```bash
# Stop all services
docker compose down

# Remove conflicting containers
docker ps -a | grep temporal
docker rm -f <container-id>

# Start services again
docker compose up -d
```

### Viewing Logs

View logs for any service:
```bash
docker compose logs -f <service-name>

# Examples:
docker compose logs -f shannon-worker
docker compose logs -f shannon-temporal
docker compose logs -f juice-shop
```

### Reset Everything

To start fresh:
```bash
cd workshop-bundle
docker compose down -v  # Remove volumes
docker compose up -d    # Start fresh
```
