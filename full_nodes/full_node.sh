#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### CONFIGURATION
### -------------------------
datadir="/var/lib/esync/mainnet"
passwordpath="$datadir/password.cfg"
jwt_file="$datadir/jwt.mainnet.hex"
network="mainnet"   # Change if using testnet
setup_script="$HOME/node-setup-current/eth2_scripts/run_setup_mainnet.ps1"
compose_file="$HOME/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml"

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
if [ ! -d "$datadir" ]; then
    echo "[*] Creating main data directory at $datadir..."
    mkdir -p "$datadir"
else
    echo "[*] Main data directory already exists, skipping..."
fi

# Ensure password.cfg is a file and prompt user for password
if [ -d "$passwordpath" ]; then
    echo "[*] Removing existing directory $passwordpath..."
    sudo rm -r "$passwordpath"
fi

if [ ! -f "$passwordpath" ]; then
    echo "[*] Creating password.cfg file..."
    read -sp "Enter a password for password.cfg: " user_password
    echo ""
    echo "$user_password" | sudo tee "$passwordpath" > /dev/null
    sudo chmod 600 "$passwordpath"
    echo "[*] Password saved to $passwordpath"
fi

# Create JWT file
if [ -f "$jwt_file" ]; then
    echo "[*] JWT secret already exists at $jwt_file, skipping generation..."
else
    echo "[*] Generating JWT secret at $jwt_file..."
    openssl rand -hex 32 > "$jwt_file"
    chmod 600 "$jwt_file"
    echo "[*] JWT secret created successfully."
fi

# Create gened directory for validator keys
gened_dir="$HOME/node-setup-current/eth2_scripts/gened"
if [ ! -d "$gened_dir" ]; then
    echo "[*] Creating gened directory at $gened_dir..."
    mkdir -p "$gened_dir"

    echo "[*] Running setup script for mainnet..."
    pushd "$gened_dir" >/dev/null
    pwsh -File "$setup_script"
    popd >/dev/null
else
    echo "[*] gened directory already exists, skipping setup..."
fi

# Create validator directory for Lighthouse if it doesn't exist
validator_dir="$datadir/datadir-eth2-validator"
if [ ! -d "$validator_dir" ]; then
    echo "[*] Creating validator data directory at $validator_dir..."
    mkdir -p "$validator_dir"
else
    echo "[*] Validator data directory already exists, skipping..."
fi

# Ensure validator keys exist
if [ ! -d "$gened_dir/validator_keys" ] || [ -z "$(ls -A "$gened_dir/validator_keys" 2>/dev/null)" ]; then
    echo "[!] ERROR: Expected validator keys in $gened_dir/validator_keys"
    echo "    Make sure run_setup_mainnet.ps1 has been executed successfully."
    exit 1
fi

### -------------------------
### IMPORT VALIDATOR KEYS
### -------------------------
docker run --rm -it \
    -v "$gened_dir/validator_keys":/keys \
    -v "$validator_dir":/root/.lighthouse \
    -v "$passwordpath":/password.cfg \
    --name validatorimport ecredits/lighthouse:latest \
    lighthouse --network "$network" account validator import \
    --datadir /root/.lighthouse \
    --directory /keys \
    --reuse-password \
    --password-file /password.cfg

### -------------------------
### CREATE .env FILE
### -------------------------
compose_dir=$(dirname "$compose_file")
env_file="$compose_dir/.env"

if [ ! -f "$env_file" ]; then
    echo "[*] Creating .env file at $env_file..."
    read -p "Set the Etherbase address: " etherbase
    read -p "Set the Fee recipient address: " fee_recipient
    self_ip=$(hostname -I | awk '{print $1}')

    cat <<EOF | tee "$env_file" > /dev/null
ETHERBASE=$etherbase
FEE_RECIPIENT=$fee_recipient
SELF_IP=$self_ip
EOF

    echo "[*] .env file created successfully."
else
    echo "[*] .env file already exists at $env_file, skipping..."
fi

### -------------------------
### START VALIDATOR NODE
### -------------------------
if ! docker compose -f "$compose_file" ps | grep -q "Up"; then
    echo "[*] Starting validator node with docker-compose..."
    docker compose -f "$compose_file" up -d
else
    echo "[*] Validator node already running, skipping..."
fi

echo "[✔] Full node + validator setup completed successfully."
