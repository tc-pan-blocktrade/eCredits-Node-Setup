#!/bin/bash

while true; do
    clear
    echo "============================="
    echo "     Docker Logs Menu"
    echo "============================="
    echo "1) Geth Logs"
    echo "2) Beacon Logs"
    echo "3) Validator Logs"
    echo "4) Exit"
    echo "============================="
    read -p "Select an option [1-4]: " choice

    case $choice in
        1)
            docker compose -f validator.mainnet.docker-compose.yaml logs -f --tail=10 geth
            ;;
        2)
            docker compose -f validator.mainnet.docker-compose.yaml logs -f --tail=10 beacon
            ;;
        3)
            docker compose -f validator.mainnet.docker-compose.yaml logs -f --tail=10 validator
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            sleep 2
            ;;
    esac
done
