#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
compose_file="$HOME/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml"

### -------------------------
### FUNCTION TO CHECK COMPOSE FILE
### -------------------------
if [ ! -f "$compose_file" ]; then
    echo "[!] ERROR: Docker Compose file not found at $compose_file"
    exit 1
fi

### -------------------------
### STOP NODES
### -------------------------
echo "[*] Stopping validator node..."
docker compose -f "$compose_file" down
echo "[*] Validator node stopped."

### -------------------------
### START NODES
### -------------------------
echo "[*] Starting validator node..."
docker compose -f "$compose_file" up -d
echo "[*] Validator node started."

### -------------------------
### STATUS
### -------------------------
echo "[*] Current node status:"
docker compose -f "$compose_file" ps
echo "[✔] Nodes restarted successfully."
