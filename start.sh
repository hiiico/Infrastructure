#!/bin/bash
set -e

echo "==========================================="
echo "Starting Vacation Planning Infrastructure"
echo "==========================================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    echo "Creating .env from example..."
    cp .env.example .env 2>/dev/null || {
        echo "Please create .env file manually with:"
        echo "MYSQL_ROOT_PASSWORD=rootpassword"
        echo "DB_USERNAME=appuser"
        echo "DB_PASSWORD=apppassword"
        echo "KAFKA_BROKER=kafka:9092"
        exit 1
    }
    echo "Created .env file from example. Please edit with your credentials."
fi

# Clean up networks
echo "Cleaning up existing networks..."
docker network ls | grep app-network && docker network rm app-network 2>/dev/null || echo "No existing app-network found"

# Build and start services
echo "Starting infrastructure services..."
docker compose up -d --build

echo ""
echo "Waiting for services to initialize..."
sleep 30

echo ""
echo "==========================================="
echo "Infrastructure started successfully!"
echo "==========================================="
echo "Kafka UI:    http://localhost:8082"
echo "MySQL:       localhost:3306"
echo ""
echo "Database credentials in .env file"
echo "To view logs: docker compose logs -f"
echo "To stop:      ./stop.sh"
echo "To test:      ./test-services.sh"
echo "==========================================="

# Show status
echo ""
echo "Service Status:"
docker compose ps

# Run health check
echo ""
echo "Running health checks..."
./test-services.sh