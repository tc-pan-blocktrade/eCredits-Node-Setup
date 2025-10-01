#!/bin/bash
set -euo pipefail

echo "🛑 Stopping Docker..."
systemctl stop docker

echo "🔥 Flushing ALL iptables rules and deleting custom chains..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -t raw -F

iptables -X
iptables -t nat -X
iptables -t mangle -X
iptables -t raw -X

# Reset default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "🧹 Removing any leftover docker network state..."
rm -rf /var/lib/docker/network/files

echo "🚀 Starting Docker..."
systemctl start docker

echo "✅ Docker restarted with clean iptables and network state."