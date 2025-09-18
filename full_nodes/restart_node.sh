#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
compose_file="$HOME/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml"
datadir="/var/lib/esync/mainnet"
passwordpath="$datadir/password.cfg"
gened_dir="$HOME/node-setup-current/eth2_scripts/gened"
validator_dir="$datadir/datadir-eth2-validator"

### -------------------------
### FUNCTION TO CHECK COMPOSE FILE
### -------------------------
if [ ! -f "$compose_file" ]; then
    echo "[!] ERROR: Docker Compose file not found at $compose_file"
    exit 1
fi

### -------------------------
### FUNCTION TO IMPORT VALIDATOR KEYS
### -------------------------
import_validator_keys() {
    if [ ! -d "$gened_dir/validator_keys" ] || [ -z "$(ls -A "$gened_dir/validator_keys" 2>/dev/null)" ]; then
        echo "[!] ERROR: No validator keys found in $gened_dir/validator_keys"
        exit 1
    fi

    echo "[*] Importing validator keys..."
    docker run --rm -it \
        -v "$gened_dir/validator_keys":/keys \
        -v "$validator_dir":/root/.lighthouse \
        -v "$passwordpath":/password.cfg \
        --name validatorimport ecredits/lighthouse:latest \
        lighthouse --network mainnet account validator import \
        --datadir /root/.lighthouse \
        --directory /keys \
        --reuse-password \
        --password-file /password.cfg
    echo "[*] Validator keys imported successfully."
}

### -------------------------
### IMPORT KEYS BEFORE RESTART
### -------------------------
import_validator_keys

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
