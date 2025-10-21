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

# Function to check if a port is open
check_port() {
    nc -z -w 2 $1 $2 > /dev/null 2>&1
}

echo
echo -e "${YELLOW}=== Container Status ===${NC}"
docker compose ps

echo
echo -e "${YELLOW}=== Network Connectivity ===${NC}"

# Check if containers can communicate with each other
echo -n "Checking inter-container network: "
docker exec api-gateway ping -c 1 shared-mysql-db > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Containers can communicate${NC}"
else
    echo -e "${RED}Container network issues detected${NC}"
fi

echo
echo -e "${YELLOW}=== Service Health Checks ===${NC}"

# Test MySQL
echo -n "MySQL Database (3306): "
docker exec shared-mysql-db mysql -u root -prootpassword -e "SELECT 1;" > /dev/null 2>&1
print_status $? "MySQL is responding"

# Test Kafka
echo -n "Kafka Broker (9092): "
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 5000 > /dev/null 2>&1
print_status $? "Kafka is responding"

# Test Kafka UI
echo -n "Kafka UI (8082): "
curl -s -f http://localhost:8082 > /dev/null 2>&1
print_status $? "Kafka UI is accessible"

# Test API Gateway
echo -n "API Gateway (80): "
curl -s -f http://localhost/actuator/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ API Gateway is healthy${NC}"
else
    echo -n "API Gateway (alternative port): "
    curl -s -f http://localhost:8080/actuator/health > /dev/null 2>&1
    print_status $? "API Gateway is healthy"
fi

echo
echo -e "${YELLOW}=== Detailed Service Information ===${NC}"

# MySQL Details
echo "MySQL Databases:"
docker exec shared-mysql-db mysql -u root -prootpassword -e "SHOW DATABASES;" 2>/dev/null || echo "  Unable to connect to MySQL"

# Kafka Details
echo "Kafka Topics:"
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 3000 2>/dev/null || echo "  Unable to list Kafka topics"

# API Gateway Details (if healthy)
echo "API Gateway Health:"
curl -s http://localhost/actuator/health 2>/dev/null | head -n 5 || curl -s http://localhost:8080/actuator/health 2>/dev/null | head -n 5 || echo "  Unable to reach API Gateway"

echo
echo -e "${YELLOW}=== Port Accessibility from Host ===${NC}"

# Check ports from host
check_port localhost 3306 && echo -e "${GREEN}✓ Port 3306 (MySQL) is open${NC}" || echo -e "${RED}✗ Port 3306 (MySQL) is closed${NC}"
check_port localhost 9092 && echo -e "${GREEN}✓ Port 9092 (Kafka) is open${NC}" || echo -e "${RED}✗ Port 9092 (Kafka) is closed${NC}"
check_port localhost 8082 && echo -e "${GREEN}✓ Port 8082 (Kafka UI) is open${NC}" || echo -e "${RED}✗ Port 8082 (Kafka UI) is closed${NC}"
check_port localhost 80 && echo -e "${GREEN}✓ Port 80 (API Gateway) is open${NC}" || echo -e "${RED}✗ Port 80 (API Gateway) is closed${NC}"

echo
echo -e "${YELLOW}=== Quick Kafka Test ===${NC}"

# Create a test topic and send a message
echo "Creating test Kafka topic..."
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create --topic infrastructure-test --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 --if-not-exists 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Sending test message to Kafka..."
    echo "Test message from infrastructure test - $(date)" | docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh --topic infrastructure-test --bootstrap-server localhost:9092 2>/dev/null

    echo "Reading test message from Kafka:"
    docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh --topic infrastructure-test --from-beginning --bootstrap-server localhost:9092 --timeout-ms 5000 2>/dev/null

    # Clean up test topic
    docker exec kafka /opt/kafka/bin/kafka-topics.sh --delete --topic infrastructure-test --bootstrap-server localhost:9092 2>/dev/null
else
    echo -e "${RED}  Unable to test Kafka messaging${NC}"
fi

echo
echo -e "${YELLOW}=== Final Status ===${NC}"

# Count successful services
SUCCESS_COUNT=0
TOTAL_TESTS=4

docker exec shared-mysql-db mysql -u root -prootpassword -e "SELECT 1;" > /dev/null 2>&1 && ((SUCCESS_COUNT++))
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --timeout-ms 3000 > /dev/null 2>&1 && ((SUCCESS_COUNT++))
curl -s -f http://localhost:8082 > /dev/null 2>&1 && ((SUCCESS_COUNT++))
curl -s -f http://localhost/actuator/health > /dev/null 2>&1 || curl -s -f http://localhost:8080/actuator/health > /dev/null 2>&1 && ((SUCCESS_COUNT++))

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}🎉 ALL SERVICES ARE OPERATIONAL ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
elif [ $SUCCESS_COUNT -ge 2 ]; then
    echo -e "${YELLOW}⚠️  MOST SERVICES ARE RUNNING ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
else
    echo -e "${RED}❌ MULTIPLE SERVICES ARE DOWN ($SUCCESS_COUNT/$TOTAL_TESTS)${NC}"
fi

echo
echo -e "${BLUE}Test completed at: $(date)${NC}"