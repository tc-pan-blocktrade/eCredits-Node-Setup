#!/usr/bin/env bash
set -euo pipefail
source ./source_env.sh

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "[!] ERROR: Docker Compose file not found at $COMPOSE_FILE"
    exit 1
fi

echo "[*] Stopping validator node..."
docker compose -f "$COMPOSE_FILE" down

echo "Removing all Docker networks..."
docker network rm $(docker network ls -q) 2>/dev/null || true

if [ -z "$(ls -A "$VALIDATOR_DIRECTORY" 2>/dev/null)" ]; then
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
else
    echo "[*] Validator keys already exist, skipping import..."
fi

echo "[*] Starting validator node..."
docker compose -f "$COMPOSE_FILE" up -d

echo "[*] Current node status:"
docker compose -f "$COMPOSE_FILE" ps
echo "[✔] Nodes restarted successfully."
