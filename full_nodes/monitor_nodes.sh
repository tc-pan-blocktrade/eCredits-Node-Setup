#!/usr/bin/env bash
set -euo pipefail

POS_VALIDATOR_CONTAINERNAME="full_nodes-validator-1"
POS_BEACON_CONTAINERNAME="full_nodes-beacon-1"
POS_GETH_CONTAINERNAME="full_nodes-geth-1"
datadir="/var/lib/esync/mainnet"
rpcport=5052  # Set to your Beacon node RPC port if different

print_node_status() {
    clear
    container_state=$(docker ps --format "{{.Names}},{{.Status}}" | grep geth)

    validator_container_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_VALIDATOR_CONTAINERNAME || true)
    IFS=',' read -r -a validator_container_status <<<"$validator_container_runs"

    validator_beacon_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_BEACON_CONTAINERNAME || true)
    IFS=',' read -r -a validator_beacon_status <<<"$validator_beacon_runs"

    validator_geth_runs=$(docker ps --format "{{.Names}},{{.Image}},{{.Status}}" | grep $POS_GETH_CONTAINERNAME || true)
    IFS=',' read -r -a validator_geth_status <<<"$validator_geth_runs"

    echo "--------------------------------------------------------------------------------"
    echo "|                              NODE STATUS                                     |"
    echo "|                            press q to return                                   |"
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
            while true; do
                print_node_status
                read -t 5 -N 1 input
                if [[ $input =~ [qQ] ]]; then
                    break
                fi
            done
            ;;
        2)
            docker compose -f ~/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml logs -f --tail=10 geth
            ;;
        3)
            docker compose -f ~/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml logs -f --tail=10 beacon
            ;;
        4)
            docker compose -f ~/node-setup-current/full_nodes/validator.mainnet.docker-compose.yaml logs -f --tail=10 validator
            ;;
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
