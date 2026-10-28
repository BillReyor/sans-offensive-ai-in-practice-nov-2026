# syntax=docker/dockerfile:1
#
# Workshop multi-stage build for ARTEX (https://github.com/lenaxia/artex).
#
# Upstream ships only a *runtime* Dockerfile that expects a pre-compiled binary
# at dist/<arch>/artex (produced by their CI), and their compose pulls the
# image `autumn27/artex` — which is not published to any public registry. So for
# the workshop we build everything from source: the Next.js frontend, then the
# Go binary with the embedded UI, then the same runtime image upstream uses.
#
# setup.sh copies this file into tools/artex/workshop.Dockerfile; docker compose
# builds it with context ./tools/artex (see the `artex` service in
# docker-compose.yml).

# --- Stage 1: build the static frontend (Next.js `output: export` -> web/out) ---
FROM node:20-bookworm AS web
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build:static

# --- Stage 2: compile the Go binary with the embedded UI ---
FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# //go:embed all:webui/dist (build tag embedui) expects the exported frontend
# at server/webui/dist.
COPY --from=web /src/web/out ./server/webui/dist
RUN CGO_ENABLED=0 go build -tags embedui -o /out/artex ./cmd/artex

# --- Stage 3: runtime (mirrors upstream Dockerfile: recon tools + Node 20 + Playwright) ---
FROM python:3.12-slim-bookworm
ARG TARGETARCH
# Common tooling plus a set of recon staples (ripgrep / curl / nmap / etc.).
# Node comes from NodeSource 20.x: bookworm's apt nodejs is 18, and Playwright
# needs >= 20.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates ripgrep curl wget vim git jq unzip \
      dnsutils iputils-ping netcat-openbsd inetutils-telnet whois nmap \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
# Pre-install Playwright MCP + CLI globally and the chromium browser, so the
# container doesn't download them over the network on first use.
RUN npm install -g @playwright/mcp@latest @playwright/cli@latest playwright@latest \
    && playwright-cli --help \
    && playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/artex /app/artex
COPY start.sh /app/start.sh
RUN chmod +x /app/artex /app/start.sh
COPY skills/ /app/skills/
# data/ (SQLite + jwt.key) persistence point — bind-mounted to ./out/artex.
VOLUME ["/app/data"]
EXPOSE 8787 8788
ENTRYPOINT ["/app/start.sh"]
CMD ["-addr", ":8787", "-proxy", ":8788"]
