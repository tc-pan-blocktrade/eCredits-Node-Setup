#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
source ./source_env.sh

### -------------------------
### FUNCTION TO CHECK COMPOSE FILE
### -------------------------
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "[!] ERROR: Docker Compose file not found at $COMPOSE_FILE"
    exit 1
fi

### -------------------------
### FUNCTION TO IMPORT VALIDATOR KEYS
### -------------------------
import_validator_keys() {
    if [ ! -d "$GENERATED_KEY_DIRECTORY" ] || [ -z "$(ls -A "$GENERATED_KEY_DIRECTORY" 2>/dev/null)" ]; then
        echo "[!] ERROR: No validator keys found in $GENERATED_KEY_DIRECTORY"
        exit 1
    fi

    echo "[*] Importing validator keys..."
    docker run --rm -it \
        -v "$GENERATED_KEY_DIRECTORY":/keys \
        -v "$VALIDATOR_DIRECTORY":/root/.lighthouse \
        -v "$PASSWORD_PATH":/password.cfg \
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
docker compose -f "$COMPOSE_FILE" down
echo "[*] Validator node stopped."

### -------------------------
### START NODES
### -------------------------
echo "[*] Starting validator node..."
docker compose -f "$COMPOSE_FILE" up -d
echo "[*] Validator node started."

### -------------------------
### STATUS
### -------------------------
echo "[*] Current node status:"
docker compose -f "$COMPOSE_FILE" ps
echo "[✔] Nodes restarted successfully."
