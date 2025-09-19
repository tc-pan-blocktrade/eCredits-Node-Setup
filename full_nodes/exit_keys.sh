#!/usr/bin/env bash
### -------------------------
### CONFIGURATION
### -------------------------
source ./source_env.sh

exit_phrase="Exit my validator"

exit_keys()
{
    echo "-------------------------------- Exit keys --------------------------------------"
    
    # Check if lighthouse datadir exists
    if [ ! -d "$VALIDATOR_DIRECTORY" ]; then
        echo "[!] Lighthouse datadir $VALIDATOR_DIRECTORY does not exist."
        echo "    Make sure you've run the validator import process first."
        exit 1
    fi
    
    # Check if validators directory exists
    if [ ! -d "$VALIDATOR_KEY_DIRECTORY" ]; then
        echo "[!] Validator keys directory $VALIDATOR_KEY_DIRECTORY does not exist."
        echo "    Checking lighthouse datadir structure:"
        ls -la "$VALIDATOR_DIRECTORY"
        exit 1
    fi
    
    cd "$VALIDATOR_KEY_DIRECTORY" || exit 1
    echo "Looking for imported validator keys in: $(pwd)"
    
    # List all validator directories
    imported_keys=$(find . -maxdepth 1 -type d -name "0x*" | sed 's|^\./||' | sort)
    
    if [ -z "$imported_keys" ]; then
        echo "[!] No validator keys found in $VALIDATOR_KEY_DIRECTORY"
        ls -la
        exit 1
    fi
    
    counter=0
    exit_all_keys="false"
    single_key_to_exit=""

    echo "Found imported validator keys:"
    for key in $imported_keys
    do
        echo "$counter: $key"
        counter=$((counter + 1))
    done
    number_of_keys=$counter
    echo "$counter: All"
    echo ""

    read -p "Select the key that should exit (0-$counter): " exit_selection
    
    # Validate selection
    if ! [[ "$exit_selection" =~ ^[0-9]+$ ]] || [ "$exit_selection" -lt 0 ] || [ "$exit_selection" -gt "$counter" ]; then
        echo "[!] Invalid selection. Please run the script again."
        exit 1
    fi
    
    counter=0
    for key in $imported_keys
    do
        if [ $counter -eq $exit_selection ]; then
            echo "[*] $key will be exited."
            single_key_to_exit=$key
            break
        fi
        counter=$((counter + 1))
    done
    
    if [ $counter -eq $number_of_keys ]; then
        echo "[*] All keys will be exited."
        exit_all_keys="true"
    fi
    
    echo ""
    read -p "Are you sure you want to proceed? This action cannot be undone. (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "[!] Exit cancelled."
        exit 0
    fi
    
    if [ "$exit_all_keys" = "false" ]; then
        exit_key "$single_key_to_exit"   
    else
        for key in $imported_keys
        do
            exit_key "$key"
        done
    fi
    
    echo "[✔] Exit process completed."
}

exit_key()
{
    local exit_key=$1
    local key_dir="$VALIDATOR_KEY_DIRECTORY/$exit_key"
    
    if [ ! -d "$key_dir" ]; then
        echo "[!] Validator directory $key_dir does not exist, skipping..."
        return
    fi
    
    cd "$key_dir" || return
    local keystore_name
    keystore_name=$(find . -name "*.json" -type f | head -n 1 | sed 's|^\./||')
    
    if [ -z "$keystore_name" ]; then
        echo "[!] No keystore file found in $key_dir, skipping..."
        return
    fi
    
    local keystore_path="$key_dir/$keystore_name"
    
    echo "[*] Exiting validator $exit_key..."
    echo "[*] Using keystore: $keystore_name"
    
expect <<EOF
    set timeout -1
    spawn docker run --rm -it --network full_nodes_ecredits \
        -v "$keystore_path:/keystore.json" \
        -v "$PASSWORD_PATH:/password.cfg" \
        --name validatorexit ecredits/lighthouse:latest \
        lighthouse --network ecs account validator exit \
        --keystore /keystore.json --password-file /password.cfg \
        --beacon-node http://beacon:5051
    expect {
        "Enter the exit phrase" {
            send "$exit_phrase\r"
            exp_continue
        }
        eof
    }
EOF

}

exit_keys
