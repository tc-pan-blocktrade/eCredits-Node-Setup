#!/usr/bin/env bash
set -euo pipefail

POS_VALIDATOR_CONTAINERNAME="full_nodes-validator-1"
POS_BEACON_CONTAINERNAME="full_nodes-beacon-1"
POS_GETH_CONTAINERNAME="full_nodes-geth-1"
datadir="/var/lib/eSync/mainnet"
rpcport=5051  # Set to your Beacon node RPC port if different

print_node_status() {
    clear
    container_state=$(docker ps --format "{{.Names}},{{.Status}}" | grep geth || true)

    validator_container_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_VALIDATOR_CONTAINERNAME || true)
    IFS=',' read -r -a validator_container_status <<<"$validator_container_runs"

    validator_beacon_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_BEACON_CONTAINERNAME || true)
    IFS=',' read -r -a validator_beacon_status <<<"$validator_beacon_runs"

    validator_geth_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_GETH_CONTAINERNAME || true)
    IFS=',' read -r -a validator_geth_status <<<"$validator_geth_runs"

    echo "--------------------------------------------------------------------------------"
    echo "|                              NODE STATUS                                     |"
    echo "|                      Refreshes every 10 seconds                               |"
    echo "|                          press q to return                                   |"
    echo "--------------------------------------------------------------------------------"

    if [[ -z $validator_container_runs ]]; then
        echo " Validator: Not running"
    else
        echo " Validator: ${validator_container_status[0]} | $(echo ${validator_container_status[1]} | awk '{print substr($0, 21)}') | ${validator_container_status[2]}"
    fi

    if [[ -z $validator_beacon_runs ]]; then
        echo " Beacon: Not running"
    else
        echo " Beacon: ${validator_beacon_status[0]} | $(echo ${validator_beacon_status[1]} | awk '{print substr($0, 21)}') | ${validator_beacon_status[2]}"
    fi

    if [[ -z $validator_geth_runs ]]; then
        echo " Geth: Not running"
    else
        echo " Geth: ${validator_geth_status[0]} | $(echo ${validator_geth_status[1]} | awk '{print substr($0, 15)}') | ${validator_geth_status[2]}"
    fi
    echo "--------------------------------------------------------------------------------"

    if [[ $container_state =~ "Up".* ]]; then
        echo " Current geth peers: $(docker exec -it $POS_GETH_CONTAINERNAME geth --exec admin.peers.length attach | sed -n 2p)"
        echo ""
        echo " Beacon node peer count: "
        curl -s -X GET "http://localhost:$rpcport/eth/v1/node/peer_count" -H 'accept: application/json'
        echo ""
        echo " Beacon health:"
        health_status_code=$(curl -o /dev/null -s -w "%{http_code}" -X GET "http://localhost:$rpcport/eth/v1/node/health")
        case $health_status_code in
            200) health_status_description="Healthy" ;;
            206) health_status_description="Syncing" ;;
            400) health_status_description="Invalid syncing" ;;
            *)   health_status_description="Not initialized / has issues" ;;
        esac
        echo "$health_status_description"

        # Count imported validator keys
        validator_keys_dir="$datadir/datadir-eth2-validator/validators"
        if [[ -d "$validator_keys_dir" ]]; then
            number_of_imported_keys_report=$(find "$validator_keys_dir" -type d -name "0x*" | wc -l)
        else
            number_of_imported_keys_report=0
        fi
        echo "Number of imported keys: $number_of_imported_keys_report"
    fi
    echo "--------------------------------------------------------------------------------"
}

follow_logs() {
    local service=$1
    echo "-----------------------------"
    echo "Showing logs for $service..."
    echo "Press q or Ctrl+C to return to menu"
    echo "-----------------------------"

    # Run docker logs in background
    docker compose -f ~/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml logs -f --tail=10 "$service" &
    LOG_PID=$!

    # Function to cleanup and exit
    cleanup_logs() {
        kill $LOG_PID 2>/dev/null || true
        wait $LOG_PID 2>/dev/null || true
        trap - INT TERM
        return 0
    }

    # Trap Ctrl+C and TERM signals
    trap cleanup_logs INT TERM

    # Monitor for 'q' key press with timeout to check if background process is still running
    while kill -0 $LOG_PID 2>/dev/null; do
        if read -t 1 -rsn1 input 2>/dev/null; then
            if [[ $input =~ [qQ] ]]; then
                cleanup_logs
                return 0
            fi
        fi
    done

    # If we get here, the docker logs process ended
    cleanup_logs
}

while true; do
    clear
    echo "============================="
    echo "   Ethereum Node Dashboard"
    echo "============================="
    echo "1) View Node Status"
    echo "2) Geth Logs"
    echo "3) Beacon Logs"
    echo "4) Validator Logs"
    echo "5) Exit"
    echo "============================="
    read -p "Select an option [1-5]: " choice

    case $choice in
        1)
            # Trap Ctrl+C to return to main menu
            trap "echo; echo 'Returning to main menu...'; trap - INT; break" INT
            while true; do
                print_node_status
                # refresh every 10 seconds or exit on keypress
                if read -t 10 -rsn1 input; then
                    if [[ $input =~ [qQ] ]]; then
                        break
                    fi
                fi
            done
            trap - INT
            ;;
        2) follow_logs geth ;;
        3) follow_logs beacon ;;
        4) follow_logs validator ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            sleep 2
            ;;
    esac
done