#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
source ./source_env.sh

echo "[*] Stopping validator node..."

if [ -f "$COMPOSE_FILE" ]; then
    docker compose -f "$COMPOSE_FILE" down
    echo "[✔] Validator node stopped and containers removed."
else
    echo "[!] ERROR: Docker Compose file not found at $COMPOSE_FILE"
    exit 1
fi

echo "[*] Listing remaining running Docker containers..."
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"