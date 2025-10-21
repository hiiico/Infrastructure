cat > init.sql << 'EOF'
-- Create both databases
CREATE DATABASE IF NOT EXISTS `vacation_planning-notifications`;
CREATE DATABASE IF NOT EXISTS `vacation_planning`;

-- Allow root user to connect from any host
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Create application user with privileges
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `vacation_planning-notifications`.* TO '${DB_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON `vacation_planning`.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
EOF