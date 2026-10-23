# Dockerfile for Shannon AI Pentester
# This file should be copied to tools/shannon/Dockerfile after cloning the Shannon repository
# Build context: ./tools/shannon

FROM node:18-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    chromium \
    chromium-driver \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm install --production

# Copy application code
COPY . .

# Build the application if necessary
RUN if [ -f "package.json" ] && grep -q '"build"' package.json; then npm run build; fi

# Set environment variables for Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# The command will be overridden by docker-compose
CMD ["node", "apps/worker/dist/temporal/worker.js", "--task-queue", "shannon"]
