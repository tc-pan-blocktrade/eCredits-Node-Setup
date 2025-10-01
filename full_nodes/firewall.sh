#!/bin/bash
set -euo pipefail

# -------------------------------
# Configuration
# -------------------------------

# Script directory
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Allowed SSH IPs (read from parent directory file)
ALLOWED_SSH_IPS=($(<"$SCRIPT_DIR/../allowed_ips.txt"))

SSH_PORT=22

# Public Ethereum P2P ports (must stay open for node)
P2P_TCP_PORTS=(30303 9000)
P2P_UDP_PORTS=(30303 9000)

# Sensitive ports (only localhost should reach)
LOCAL_ONLY_PORTS=(6061 8545 8551 9001 5051 8080 8081)

# -------------------------------
# Reset chains (safe reset, not full flush)
# -------------------------------
iptables -F DOCKER-USER
iptables -F INPUT

# Set default policies (secure baseline)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Disable IPv6 completely (all DROP)
ip6tables -F
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# -------------------------------
# Common rules
# -------------------------------
iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# -------------------------------
# SSH lockdown (host)
# -------------------------------
for ip in "${ALLOWED_SSH_IPS[@]}"; do
    iptables -A INPUT -p tcp -s "$ip" --dport $SSH_PORT -j ACCEPT
done
iptables -A INPUT -p tcp --dport $SSH_PORT -j DROP

# -------------------------------
# SSH lockdown (Docker containers)
# -------------------------------
for ip in "${ALLOWED_SSH_IPS[@]}"; do
    iptables -A DOCKER-USER -p tcp -s "$ip" --dport $SSH_PORT -j ACCEPT
done
iptables -A DOCKER-USER -p tcp --dport $SSH_PORT -j DROP

# -------------------------------
# Ethereum P2P networking
# -------------------------------
for port in "${P2P_TCP_PORTS[@]}"; do
    iptables -A DOCKER-USER -p tcp --dport $port -j ACCEPT
done
for port in "${P2P_UDP_PORTS[@]}"; do
    iptables -A DOCKER-USER -p udp --dport $port -j ACCEPT
done

# -------------------------------
# Local-only ports (block external)
# -------------------------------
for port in "${LOCAL_ONLY_PORTS[@]}"; do
    iptables -A DOCKER-USER -p tcp -s 127.0.0.1 --dport $port -j ACCEPT
    iptables -A DOCKER-USER -p tcp --dport $port -j DROP
done

# -------------------------------
# Default allow for other Docker traffic
# -------------------------------
iptables -A DOCKER-USER -j ACCEPT

echo "✅ Firewall rules applied: Host SSH restricted + Docker traffic locked down + IPv6 disabled."
