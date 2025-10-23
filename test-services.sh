#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Vacation Planning Infrastructure Test ===${NC}"
echo "Testing all services and their connectivity..."

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

echo
echo -e "${YELLOW}=== Container Status ===${NC}"
docker compose ps

echo
echo -e "${YELLOW}=== Service Health Checks ===${NC}"

# Test MySQL (internal network only)
echo -n "MySQL Database (internal): "
docker exec shared-mysql-db mysql -u root -p${MYSQL_ROOT_PASSWORD:-rootpassword} -e "SELECT 1;" > /dev/null 2>&1
print_status $? "MySQL is responding internally"

# Test Kafka (internal network only)
echo -n "Kafka Broker (internal): "
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 5000 > /dev/null 2>&1
print_status $? "Kafka is responding internally"

# Test Kafka UI (exposed to host)
echo -n "Kafka UI (8082): "
curl -s -f http://localhost:8082 > /dev/null 2>&1
print_status $? "Kafka UI is accessible"

# Test inter-container communication
echo -n "Container network connectivity: "
docker exec kafka ping -c 1 shared-mysql-db > /dev/null 2>&1
print_status $? "Containers can communicate internally"

echo
echo -e "${YELLOW}=== Detailed Service Information ===${NC}"

# MySQL Details
echo "MySQL Databases:"
docker exec shared-mysql-db mysql -u root -p${MYSQL_ROOT_PASSWORD:-rootpassword} -e "SHOW DATABASES;" 2>/dev/null || echo "  Unable to connect to MySQL"

# Kafka Details
echo "Kafka Topics:"
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 3000 2>/dev/null || echo "  Unable to list Kafka topics"

echo
echo -e "${YELLOW}=== Port Accessibility from Host ===${NC}"

# Check ports from host (only exposed services)
echo -e "${YELLOW}Note: MySQL (3306) and Kafka (9092) are not exposed to host${NC}"
check_port() {
    nc -z -w 2 $1 $2 > /dev/null 2>&1
}

check_port localhost 8082 && echo -e "${GREEN}✓ Port 8082 (Kafka UI) is open${NC}" || echo -e "${RED}✗ Port 8082 (Kafka UI) is closed${NC}"

echo
echo -e "${YELLOW}=== Quick Kafka Test ===${NC}"

# Create a test topic and send a message (internal network)
echo "Creating test Kafka topic..."
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create --topic infrastructure-test --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 --if-not-exists 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Sending test message to Kafka..."
    echo "Test message from infrastructure test - $(date)" | docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh --topic infrastructure-test --bootstrap-server localhost:9092 2>/dev/null

    echo "Reading test message from Kafka:"
    docker exec kafka timeout 5s /opt/kafka/bin/kafka-console-consumer.sh --topic infrastructure-test --from-beginning --bootstrap-server localhost:9092 --timeout-ms 5000 2>/dev/null

    # Clean up test topic
    docker exec kafka /opt/kafka/bin/kafka-topics.sh --delete --topic infrastructure-test --bootstrap-server localhost:9092 2>/dev/null
    echo -e "${GREEN}✓ Kafka messaging test completed${NC}"
else
    echo -e "${RED}  Unable to test Kafka messaging${NC}"
fi

echo
echo -e "${YELLOW}=== Database Initialization Check ===${NC}"

# Check if databases were created from init.sql
echo "Checking database initialization:"
docker exec shared-mysql-db mysql -u root -p${MYSQL_ROOT_PASSWORD:-rootpassword} -e "SHOW DATABASES;" 2>/dev/null | grep -v "information_schema\|mysql\|performance_schema\|sys" || echo "  No application databases found"

echo
echo -e "${YELLOW}=== Final Status ===${NC}"

# Count successful services
SUCCESS_COUNT=0
TOTAL_TESTS=4

docker exec shared-mysql-db mysql -u root -p${MYSQL_ROOT_PASSWORD:-rootpassword} -e "SELECT 1;" > /dev/null 2>&1 && ((SUCCESS_COUNT++))
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 3000 > /dev/null 2>&1 && ((SUCCESS_COUNT++))
curl -s -f http://localhost:8082 > /dev/null 2>&1 && ((SUCCESS_COUNT++))
docker exec kafka ping -c 1 shared-mysql-db > /dev/null 2>&1 && ((SUCCESS_COUNT++))

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}🎉 ALL SERVICES ARE OPERATIONAL ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
    echo -e "${GREEN}Infrastructure is ready for application services${NC}"
elif [ $SUCCESS_COUNT -ge 2 ]; then
    echo -e "${YELLOW}⚠️  MOST SERVICES ARE RUNNING ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
else
    echo -e "${RED}❌ MULTIPLE SERVICES ARE DOWN ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
fi

echo
echo -e "${BLUE}Test completed at: $(date)${NC}"