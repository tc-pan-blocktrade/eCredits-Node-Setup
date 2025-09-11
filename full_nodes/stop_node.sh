#!/usr/bin/env bash
set -euo pipefail

compose_file="$HOME/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml"

echo "[*] Stopping validator node..."

if [ -f "$compose_file" ]; then
    docker compose -f "$compose_file" down
    echo "[✔] Validator node stopped and containers removed."
else
    echo "[!] ERROR: Docker Compose file not found at $compose_file"
    exit 1
fi

echo "[*] Listing remaining running Docker containers..."
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"
