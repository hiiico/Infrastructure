cat > init-wrapper.sh << 'EOF'
#!/bin/bash
set -e

# Execute SQL with environment variables
mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE IF NOT EXISTS \`vacation_planning-notifications\`;
CREATE DATABASE IF NOT EXISTS \`vacation_planning\`;
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`vacation_planning-notifications\`.* TO '${DB_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON \`vacation_planning\`.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
EOF
EOF