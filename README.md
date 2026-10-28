# SANS Workshop — Offensive AI in Practice
## Hands-on exploitation of a vulnerable app with open-source pentest tools · November 2026

In this lab you run three open-source, AI-assisted pentest tools — **ZAP**, **Shannon**, and **PentestGPT** — against a deliberately vulnerable web app (**OWASP Juice Shop**), all wired together with Docker Compose. Everything runs in containers on your own machine (or in a GitHub Codespace).

> **Do this at home before the workshop.** Run the setup and `./verify-setup.sh` on the same laptop and network you'll use on the day, at least a few days ahead. The verify step makes one live model call with your Anthropic API key (a few cents, no scan) to confirm the key works.

---

## Table of Contents

- [Before you start: cost & API credit](#before-you-start-cost--api-credit)
- [Prerequisites](#prerequisites)
- [Choose your path](#choose-your-path)
- [Setup](#setup)
- [Verify your setup](#verify-your-setup)
- [What you now have](#what-you-now-have)
- [Recommended running order](#recommended-running-order)
- [Run ZAP baseline](#run-zap-baseline)
- [Run Shannon](#run-shannon)
- [Run PentestGPT](#run-pentestgpt)
- [Where reports are saved](#where-reports-are-saved)
- [Resetting between runs](#resetting-between-runs)
- [Troubleshooting](#troubleshooting)
- [Quick reference (cheat sheet)](#quick-reference-cheat-sheet)

---

## Before you start: cost & API credit

Shannon and PentestGPT both call the Anthropic API on **your** key. ZAP does not use the API at all.

- **Load at least $40 of credit** on your Anthropic account, and make sure any spend limit on your organization or workspace allows it.
- **A completed lite Shannon run costs about $25–30.** One measured run in October 2026 cost **$27.01** (81 minutes, 217 turns, 8 agents). A PentestGPT session adds only ~$2.
- **If credit runs out mid-scan, every Shannon agent fails at once** with a non-retryable error, and you lose the run. `verify-setup.sh` makes a live call to check your key works but **cannot** detect low credit — so give yourself headroom.

> Earlier drafts of this README suggested "$15–20" and a $25 floor. That figure came from a run that was *stopped early* and extrapolated; a run that completes costs more. Budget for $40.

---

## Prerequisites

- **Docker + Docker Compose** — Docker Desktop: https://www.docker.com/products/docker-desktop/
- **An Anthropic API key** — https://platform.claude.com/ (see [cost & API credit](#before-you-start-cost--api-credit))
- **Resources:** at least **8 GB of memory** available to Docker and about **20 GB of free disk**.
- **Free ports:** `3000`, `7233`, and `8233`.
- **Outbound network** to `api.anthropic.com`, Docker Hub, GitHub, npm, PyPI, and the Ubuntu package mirrors. A TLS-inspecting proxy breaks the image builds and the API calls.

Clone this repository:

```bash
# HTTPS (works everywhere)
git clone https://github.com/rpigu-i/sans-offensive-ai-in-practice-nov-2026.git

# …or SSH, if you have GitHub SSH keys set up
git clone git@github.com:rpigu-i/sans-offensive-ai-in-practice-nov-2026.git
```

---

## Choose your path

Pick the one that matches your machine, then jump to [Setup](#setup):

- **Local on macOS / Linux** — the default. Just install Docker Desktop and continue to [Setup](#setup).
- **Windows** — see [Windows participants](#windows-participants) below, then [Setup](#setup).
- **No Docker allowed (locked-down laptop)** — run the whole lab in a browser via [GitHub Codespaces](#github-codespaces).

### Windows participants

The easiest option on Windows is [Codespaces](#github-codespaces). To run locally instead, note that all setup scripts and the tool containers are Linux, so run everything **inside WSL2** (recommended):

1. Install Docker Desktop with the WSL2 backend, and turn on integration for your Ubuntu distribution (Docker Desktop → Settings → Resources → WSL integration).
2. Open an **Ubuntu (WSL) terminal** and clone this repository into your Linux home folder (`cd ~`), **not** under `/mnt/c/...`. Files on the Windows drive are slow to share with containers, are scanned by endpoint security, and can end up with Windows line endings.
3. Run `./setup.sh` and the rest of [Setup](#setup) from that terminal. On Linux and WSL2, `setup.sh` records your user ID in `.env` so Shannon can write its findings to your folders.

**If you must use Git Bash instead of WSL2:**
- Before cloning anything, run `git config --global core.autocrlf input`. Git for Windows otherwise converts files to Windows (CRLF) line endings, and the scripts and containers fail with errors like `$'\r': command not found` or `/usr/bin/env: 'bash\r': No such file or directory`.
- Put `MSYS_NO_PATHCONV=1` in front of the Shannon `docker compose run` commands. Without it, Git Bash rewrites `/app/repos/...` into a Windows path.
- Don't use PowerShell or Command Prompt: the multi-line commands use bash `\` line continuations.

**Corporate laptops: check these with IT before the workshop.**
- **Docker Desktop:** must be allowed and licensed (larger companies need a paid Docker subscription), with virtualization and WSL2 enabled.
- **Endpoint security:** it may flag or quarantine ZAP, nmap, or the deliberately vulnerable Juice Shop source. Ask for an exception, or use a non-corporate machine.

### GitHub Codespaces

If you can't install Docker on your laptop, run the whole lab in a Codespace. You only need a browser and a GitHub account.

1. **Add your API key as a Codespaces secret** before you create the codespace: github.com → your profile → **Settings → Codespaces → Secrets → New secret**. Name it `ANTHROPIC_API_KEY`, paste your key, and give this repository access to it. Don't put the key in a file in the repository.
2. **Create the codespace:** on the repository page, click **Code → Codespaces → Create codespace on main**. Choose a machine with at least **4 cores** if asked.
3. **Wait for setup.** The first start clones the tools and builds the Docker images, which takes several minutes. When it finishes, the lab services start automatically.
4. **Verify:** in the codespace terminal, run `cd workshop-bundle && ./verify-setup.sh`.
5. **Run the tools** with the commands below, from `workshop-bundle/` in the codespace terminal. Open the **Ports** tab to reach Juice Shop (3000) and the Temporal UI (8233) in your browser.

**Cost:** personal GitHub accounts include 120 core-hours of Codespaces a month for free (~30 hours on a 4-core machine). **Stop the codespace when you're not using it**, and delete it after the workshop. Try this a few days early — some corporate networks block Codespaces.

---

## Setup

All commands run from the **`workshop-bundle/`** directory — that's where `docker-compose.yml` lives.

```bash
cd sans-offensive-ai-in-practice-nov-2026/workshop-bundle
./setup.sh                    # clones the tools + Juice Shop source, creates folders
# Edit .env and add your ANTHROPIC_API_KEY
docker compose up -d          # start all services
```

`setup.sh` does everything the lab needs:
1. Creates the `tools/` and `workspace/` structure and the `out/` report folders.
2. Clones **Shannon** and **PentestGPT** (PentestGPT is pinned to commit `b986930`, the last version with the `pentestgpt` command).
3. Copies the Shannon configs (`juice-shop.yaml`, `juice-shop-lite.yaml`) into place.
4. Clones the **Juice Shop source** into `workspace/juice-shop/` (Shannon analyzes it as a white-box target) and sets a local git identity for it.

> **Note:** both Shannon and PentestGPT ship their own `Dockerfile`, and Docker Compose builds from those. **Don't overwrite them** with the files in `workshop-bundle/dockerfiles/` — those are outdated fallbacks that no longer build against current upstream code.

> **Note:** `docker compose up -d` also starts the `zap-baseline` service, which runs a one-shot ZAP scan immediately and then exits. That's expected — you'll see a `zap-baseline` container do ~5 minutes of work on startup. You can re-run it on demand later (see [Run ZAP baseline](#run-zap-baseline)).

<details>
<summary><strong>Manual setup (alternative — if you'd rather run each step yourself)</strong></summary>

```bash
cd workshop-bundle

# 1. API key
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY

# 2. Clone the tools
mkdir -p tools
git clone https://github.com/KeygraphHQ/shannon tools/shannon
git clone https://github.com/greydgl/pentestgpt tools/PentestGPT
# Upstream removed the `pentestgpt` command on 2026-07-13; pin to the last version that has it
git -C tools/PentestGPT checkout b986930

# 3. Shannon config
mkdir -p tools/shannon/configs
cp ../juice-shop.yaml tools/shannon/configs/juice-shop.yaml
cp ../juice-shop-lite.yaml tools/shannon/configs/juice-shop-lite.yaml

# 4. Juice Shop source (Shannon's white-box target)
git clone https://github.com/juice-shop/juice-shop.git workspace/juice-shop
cd workspace/juice-shop
git config user.email "pentest@localhost"
git config user.name "Pentest Agent"
cd ../..

# 5. Start services
docker compose up -d
```

The `git config` lines set a committer identity for the Juice Shop repo only — Shannon creates git checkpoints during pre-recon, which requires a configured user even though nothing is pushed upstream.

</details>

### If a key is already exported in your shell

Docker Compose reads `ANTHROPIC_API_KEY` from your environment **in preference to** `.env`. If you've exported the key in your shell (or a dotfile), editing `.env` has no effect — Compose keeps using the exported value. Either update it where it's exported, or `unset ANTHROPIC_API_KEY` in the terminal you run Compose from so `.env` wins.

---

## Verify your setup

```bash
docker compose ps          # all services should be Up (healthy)
./verify-setup.sh          # checks files, services, and makes one live key-check call
```

`verify-setup.sh` makes **one** live model call (a few cents, no scan) to confirm your key works and passes Shannon's security-access check. Fix any ✗ errors it reports before the workshop.

You should see these services:
- `juice-shop` — Up (healthy)
- `shannon-postgres` — Up (healthy)
- `shannon-temporal` — Up (healthy)
- `shannon-temporal-ui` — Up
- `pentestgpt` — Up
- (`shannon-worker` is **not** listed here — it's a one-shot job you launch with `docker compose run`; see [Run Shannon](#run-shannon).)

**Monitor URLs:**
- Juice Shop: http://localhost:3000
- Temporal UI: http://localhost:8233

---

## What you now have

<details>
<summary>Directory map (after setup)</summary>

```
sans-offensive-ai-in-practice-nov-2026/
├── README.md                          <-- You are here
└── workshop-bundle/
    ├── .env                           <-- Your API keys (copy from .env.example)
    ├── .env.example
    ├── docker-compose.yml             <-- Defines all services (run compose from here)
    │
    ├── tools/                         <-- Cloned tool repositories
    │   ├── shannon/                   <-- git clone https://github.com/KeygraphHQ/shannon
    │   │   ├── Dockerfile
    │   │   ├── apps/
    │   │   ├── configs/               <-- juice-shop.yaml, juice-shop-lite.yaml
    │   │   └── ...
    │   └── PentestGPT/                <-- git clone https://github.com/greydgl/pentestgpt (pinned b986930)
    │       ├── Dockerfile
    │       └── ...
    │
    ├── workspace/                     <-- Shared working dir (mounted into containers)
    │   └── juice-shop/                <-- Target source for Shannon
    │       └── .shannon/deliverables/ <-- Shannon's security reports land here
    │
    └── out/                           <-- Tool output / reports
        ├── zap/                       <-- ZAP scan reports
        └── shannon/                   <-- Shannon audit logs and session data
```

- The `tools/` directory holds **full git clones** of Shannon and PentestGPT — Compose needs each repo's `Dockerfile` to build the worker containers.
- `workspace/` is mounted into both Shannon and PentestGPT, so findings persist on your host.
- `out/` collects reports from ZAP and Shannon.

</details>

---

## Recommended running order

The three tools are independent and **safe to run at the same time** — they don't interfere with each other (separate outputs, no port or container clashes). Because Shannon is by far the longest, start it first and do the others while it works:

1. **Start Shannon first** ([Run Shannon](#run-shannon)) — the lite run takes roughly an hour. Kick it off and leave it.
2. **While Shannon runs**, do the [ZAP baseline](#run-zap-baseline) (~5 min) and a [PentestGPT session](#run-pentestgpt) (~10–20 min). Both share the live Juice Shop target with Shannon without any problem.
3. **Come back to Shannon** when it finishes and review its report.

> Remember all three AI tools draw on the same API credit (ZAP is free). See [cost & API credit](#before-you-start-cost--api-credit).

---

## Run ZAP baseline

```bash
docker compose run --rm zap-baseline
# report at: ./out/zap/zap_baseline_report.html
```

This passive baseline scan takes about five minutes. The scan script ships in the official ZAP image.

> **Exit code 2 is normal.** ZAP baseline exits non-zero when it finds **warnings** (exit 2) or failures (exit 1); Juice Shop always produces warnings, so a clean run still "exits 2". That is **not** an error — check the report for the `PASS/WARN/FAIL` summary.

---

## Run Shannon

Shannon is a **white-box** AI pentester: it analyzes the target's source code to guide its exploitation strategy. The services from [Setup](#setup) should already be running.

Shannon writes intermediate findings into `workspace/juice-shop/.shannon/`. The Juice Shop source was cloned there by `setup.sh` — **you only need to re-clone it when resetting** between runs (see [Resetting between runs](#resetting-between-runs)).

> ⚠️ **Don't point Shannon at an empty repo.** Its pre-recon agents will spin for hundreds of turns looking for code that isn't there, and may fall back on stale deliverables — producing hallucinated findings instead of real ones.

### Workshop lite run (use this in the workshop)

Each participant runs Shannon on their own API key, so the workshop uses the smaller `juice-shop-lite.yaml`:

- `exploit: "false"` — runs recon and vulnerability analysis, skips the exploitation phase
- Focuses on two endpoints only: `/rest/user/login` and `/api/Users`

**Time and cost: about an hour, ~$25–30 per run** (see [cost & API credit](#before-you-start-cost--api-credit)). The focus rules don't shorten the first two phases, which analyze the whole Juice Shop codebase. Reference timings:

| Phase | Time |
|---|---|
| Login check | ~2 min |
| Pre-Recon | ~17 min |
| Recon | ~16 min |
| Vulnerability analysis (5 agents in parallel) | remainder |

Start the scan early and work on other material while it runs.

```bash
docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \
  http://juice-shop:3000 \
  /app/repos/juice-shop \
  --task-queue shannon \
  --config /app/configs/juice-shop-lite.yaml
```

If a live run fails, use the complete set of Shannon results in `example_deliverables/` to follow along.

### Full run (every phase, including exploitation)

The full configuration runs every phase, including exploitation. It takes longer and costs more than the lite run (a test run spent ~$28 before the account ran out of credit partway through exploitation):

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

### Monitor progress

- **Temporal Web UI** (recommended): http://localhost:8233 — real-time workflow execution, activity history, task queues.
- **Worker logs:** `docker compose logs -f shannon-worker`
- **Workflow status:** `docker compose exec shannon-worker node apps/worker/dist/temporal/query.js <workflow-id>`

The pentest runs through 5 phases: **Pre-Recon** → **Recon** → **Vulnerability Analysis** (5 parallel agents: injection, xss, auth, authz, ssrf) → **Exploitation** → **Reporting**.

### Results

- `workspace/juice-shop/.shannon/deliverables/` — security findings and reports
- `out/shannon/` — audit logs and session data

---

## Run PentestGPT

PentestGPT is included in `tools/PentestGPT/` and its container starts with `docker compose up -d`.

### Connect and run

```bash
docker compose exec -it pentestgpt bash   # drops you into /workspace
pentestgpt --target juice-shop:3000 --no-telemetry
```

Or with specific instructions:

```bash
pentestgpt --target juice-shop:3000 --no-telemetry --instruction "Focus on authentication bypass vulnerabilities"
```

> **Telemetry:** PentestGPT sends usage data to Langfuse (`us.cloud.langfuse.com`) unless you pass `--no-telemetry`. Every command here includes it.

### Common options

```bash
pentestgpt --target juice-shop:3000 --no-telemetry                 # Default mode (ctf: depth-first exploitation)
pentestgpt --target juice-shop:3000 --no-telemetry --mode pentest  # Breadth-first vulnerability identification
pentestgpt --target juice-shop:3000 --no-telemetry -v              # Verbose
pentestgpt --list-sessions                                         # List previous sessions
pentestgpt --target juice-shop:3000 --no-telemetry --resume --session-id <id>
```

PentestGPT prints progress as plain text: each stage (e.g. `[Stage 1/3] Asset Identification`), then every tool it runs (`[TOOL] Bash: ...`). It runs Claude Code inside the container with permission prompts off, so the commands it chooses run immediately — the container is the safety boundary.

### Output

The walkthrough it generates persists on your host at:

- `workshop-bundle/workspace/workspace/juice-shop-walkthrough.md`

It also prints a final report to the screen and saves a copy to `/tmp/FINAL_REPORT.md`, and keeps session state under `~/.pentestgpt/sessions`. **Both live inside the container and are *not* mounted, so they are lost when the container is recreated or removed.** To keep the final report, copy it out first:

```bash
docker compose cp pentestgpt:/tmp/FINAL_REPORT.md out/pentestgpt-FINAL_REPORT.md
```

To stop it, press **Ctrl+C**. If anything is still running, restart the container: `docker compose restart pentestgpt`.

> **`ENOENT: ... uv_cwd` error?** The container needs recreating: `docker compose up -d pentestgpt`.

---

## Where reports are saved

All host paths are relative to `workshop-bundle/`. Anything under `workspace/` or `out/` is bind-mounted, so it persists after a run.

| Tool | Report / output | Host path |
| --- | --- | --- |
| **ZAP** | Baseline scan report (HTML) | `out/zap/zap_baseline_report.html` |
| **Shannon** | Security findings and reports | `workspace/juice-shop/.shannon/deliverables/` |
| **Shannon** | Audit logs and session data | `out/shannon/` |
| **PentestGPT** | Generated walkthrough (Markdown) | `workspace/workspace/juice-shop-walkthrough.md` |

**Not saved to the host.** PentestGPT's `/tmp/FINAL_REPORT.md` and `~/.pentestgpt/sessions` live *inside* the container and are lost when it's recreated. Copy the report out if you want to keep it (command above).

> In a codespace the same paths apply under the repository root. Use **Download…** in the file explorer, or `gh codespace cp`, to pull a report onto your laptop.

---

## Resetting between runs

Shannon writes intermediate findings to `.shannon/deliverables/` inside the target repo. If you run Shannon again without clearing this, the new run ingests the previous run's output and its analysis degrades.

**Easy way:**
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

`git clean -fdx` removes untracked files (including anything Shannon dropped outside `.shannon/`), and `git reset --hard` reverts modifications Shannon's exploit attempts may have made to tracked files.

---

## Troubleshooting

### Shannon scan taking too long
1. **Check for stale deliverables.** If you didn't reset between runs, Shannon may be ingesting old findings and looping — run the [reset](#resetting-between-runs) commands.
2. **Verify the config loaded.** Early in the worker log, look for `Configuration file OK` with `configPath: '/app/configs/juice-shop-lite.yaml'`. If it's missing, the `--config` flag isn't being picked up and the scan has no scope limits.
3. **Narrow the `focus` rules** in the config further — fewer focus paths means fewer hypotheses and less exploit-phase work.

### Shannon Temporal not starting
"dependency failed to start: container shannon-temporal exited (1)":
```bash
docker compose logs shannon-temporal
docker compose ps shannon-postgres          # ensure Postgres is healthy
docker compose restart shannon-temporal
```

### Port already in use
If `7233` or `8233` is already allocated:
```bash
docker compose down
docker ps -a | grep temporal
docker rm -f <container-id>
docker compose up -d
```

### Viewing logs
```bash
docker compose logs -f <service-name>   # e.g. shannon-worker, shannon-temporal, juice-shop
```

### Reset everything
```bash
cd workshop-bundle
docker compose down -v   # remove volumes
docker compose up -d
```

---

## Quick reference (cheat sheet)

For when you've done the setup once and just need the commands.

```bash
# First-time setup
cd sans-offensive-ai-in-practice-nov-2026/workshop-bundle
./setup.sh
# Edit .env and add your ANTHROPIC_API_KEY
docker compose up -d
./verify-setup.sh

# ZAP baseline (~5 min; exit 2 = warnings, not an error)
docker compose run --rm zap-baseline

# Shannon lite run (analysis only, two endpoints)
docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \
  http://juice-shop:3000 /app/repos/juice-shop \
  --task-queue shannon --config /app/configs/juice-shop-lite.yaml

# PentestGPT session (--no-telemetry turns off data sent to Langfuse)
docker compose exec -it pentestgpt bash
pentestgpt --target juice-shop:3000 --no-telemetry

# Reset Shannon's workspace between runs
./reset-workspace.sh
```

**Monitor:** Juice Shop http://localhost:3000 · Temporal UI http://localhost:8233
