#!/bin/bash
set -e

echo "==========================================="
echo "Stopping Vacation Planning Infrastructure"
echo "==========================================="

# Stop all services
docker compose down

echo ""
echo "All infrastructure services stopped."

# Ask about network cleanup
read -p "Do you want to remove the app-network? (y/n): " remove_network
if [ "$remove_network" = "y" ]; then
    docker network rm app-network 2>/dev/null && echo "Network removed." || echo "Network not found or in use."
else
    echo "Network 'app-network' preserved for future use."
fi

echo "To completely remove data volumes, run: docker volume prune"