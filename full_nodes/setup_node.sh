#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
source ./source_env.sh

### -------------------------
### SYSTEM PREPARATION
### -------------------------
echo "[*] Updating package lists..."
sudo apt-get update -y

echo "[*] Installing prerequisites..."
sudo apt-get install -y ca-certificates curl wget apt-transport-https software-properties-common

# Setup Docker repo key
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    echo "[*] Adding Docker GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
else
    echo "[*] Docker GPG key already exists, skipping..."
fi

# Setup Docker repository
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo "[*] Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
else
    echo "[*] Docker repository already configured, skipping..."
fi

# Install Expect
if ! command -v expect &>/dev/null; then
    echo "[*] Installing Expect..."
    sudo apt-get update
    sudo apt-get install -y expect
else
    echo "[*] Expect already installed, skipping..."
fi

# Install Docker
if ! command -v docker &>/dev/null; then
    echo "[*] Installing Docker..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "[*] Docker already installed, skipping..."
fi

# Run Docker test container
if ! sudo docker run --rm hello-world >/dev/null 2>&1; then
    echo "[*] Running Docker hello-world test..."
    sudo docker run hello-world
else
    echo "[*] Docker hello-world test already successful, skipping..."
fi

# Add current user to docker group
if groups $USER | grep -q '\bdocker\b'; then
    echo "[*] User $USER already in docker group, skipping..."
else
    echo "[*] Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    echo "==> You may need to log out and back in for group changes to take effect."
fi

# Setup Microsoft repository for PowerShell
if [ ! -f packages-microsoft-prod.deb ]; then
    echo "[*] Downloading Microsoft repo key..."
    wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
else
    echo "[*] Microsoft repo deb already downloaded, skipping..."
fi

if ! dpkg -l | grep -q packages-microsoft-prod; then
    echo "[*] Registering Microsoft repo..."
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update -y
else
    echo "[*] Microsoft repo already registered, skipping..."
fi

# Install PowerShell
if ! command -v pwsh &>/dev/null; then
    echo "[*] Installing PowerShell..."
    sudo apt-get install -y powershell
else
    echo "[*] PowerShell already installed, skipping..."
fi

### -------------------------
### ENSURE DATA DIRECTORIES
### -------------------------
if [ ! -d "$DATA_DIRECTORY" ]; then
    echo "[*] Creating main data directory at $DATA_DIRECTORY..."
    mkdir -p "$DATA_DIRECTORY"
else
    echo "[*] Main data directory already exists, skipping..."
fi

# Ensure password.cfg is a file and prompt user for password
if [ -d "$PASSWORD_PATH" ]; then
    echo "[*] Removing existing directory $PASSWORD_PATH..."
    sudo rm -r "$PASSWORD_PATH"
fi

if [ ! -f "$PASSWORD_PATH" ]; then
    echo "[*] Creating password.cfg file..."
    read -sp "Enter a password for password.cfg: " user_password
    echo ""
    echo "$user_password" | sudo tee "$PASSWORD_PATH" > /dev/null
    sudo chmod 600 "$PASSWORD_PATH"
    echo "[*] Password saved to $PASSWORD_PATH"
fi

# Create JWT file
if [ -f "$JWT_FILE" ]; then
    echo "[*] JWT secret already exists at $JWT_FILE, skipping generation..."
else
    echo "[*] Generating JWT secret at $JWT_FILE..."
    openssl rand -hex 32 > "$JWT_FILE"
    chmod 600 "$JWT_FILE"
    echo "[*] JWT secret created successfully."
fi

# Create gened directory for validator keys
if [ ! -d "$GENERATED_DIRECTORY" ]; then
    echo "[*] Creating gened directory at $GENERATED_DIRECTORY..."
    mkdir -p "$GENERATED_DIRECTORY"

    echo "[*] Running setup script for mainnet..."
    pushd "$GENERATED_DIRECTORY" >/dev/null
    pwsh -File "$KEY_GENERATION_AND_STAKING_SCRIPT"
    popd >/dev/null
else
    echo "[*] gened directory already exists, skipping setup..."
fi

# Create validator directory for Lighthouse if it doesn't exist
if [ ! -d "$VALIDATOR_DIRECTORY" ]; then
    echo "[*] Creating validator data directory at $VALIDATOR_DIRECTORY..."
    mkdir -p "$VALIDATOR_DIRECTORY"
else
    echo "[*] Validator data directory already exists, skipping..."
fi

# Ensure validator keys exist
if [ ! -d "$GENERATED_KEY_DIRECTORY" ] || [ -z "$(ls -A "$GENERATED_KEY_DIRECTORY" 2>/dev/null)" ]; then
    echo "[!] ERROR: Expected validator keys in $GENERATED_KEY_DIRECTORY"
    echo "    Make sure run_setup_mainnet.ps1 has been executed successfully."
    exit 1
fi

### -------------------------
### IMPORT VALIDATOR KEYS
### -------------------------
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

### -------------------------
### CREATE .env FILE
### -------------------------

if [ ! -f "$ENV_FILE" ]; then
    echo "[*] Creating .env file at $ENV_FILE..."
    read -p "Set the Etherbase address: " etherbase_address
    read -p "Set the Fee recipient address: " fee_recipient_address
    external_ip=$(hostname -I | awk '{print $1}')

    cat <<EOF | tee "$ENV_FILE" > /dev/null
ETHERBASE_ADDRESS=$etherbase_address
FEE_RECIPIENT_ADDRESS=$fee_recipient_address
EXTERNAL_IP=$external_ip
EOF

    echo "[*] .env file created successfully."
else
    echo "[*] .env file already exists at $ENV_FILE, skipping..."
fi

### -------------------------
### START VALIDATOR NODE
### -------------------------
if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
    echo "[*] Starting validator node with docker-compose..."
    docker compose -f "$COMPOSE_FILE" up -d
else
    echo "[*] Validator node already running, skipping..."
fi

echo "[✔] Full node + validator setup completed successfully."