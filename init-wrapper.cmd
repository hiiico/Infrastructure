@echo off
echo Creating databases if they don't exist...

:: Create vacation_planning-notifications database
mysql -u root -p%MYSQL_ROOT_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS \`vacation_planning-notifications\`;"
if %errorlevel% neq 0 (
    echo Failed to create vacation_planning-notifications database
    exit /b 1
)
echo Database vacation_planning-notifications created or already exists

:: Create vacation_planning database
mysql -u root -p%MYSQL_ROOT_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS \`vacation_planning\`;"
if %errorlevel% neq 0 (
    echo Failed to create vacation_planning database
    exit /b 1
)
echo Database vacation_planning created or already exists

:: Optional: Grant privileges to a specific user (adjust as needed)
mysql -u root -p%MYSQL_ROOT_PASSWORD% -e "GRANT ALL PRIVILEGES ON \`vacation_planning-notifications\`.* TO '${DB_USERNAME}'@'%';"
mysql -u root -p%MYSQL_ROOT_PASSWORD% -e "GRANT ALL PRIVILEGES ON \`vacation_planning\`.* TO '${DB_USERNAME}'@'%';"

echo Both databases created successfully
echo Running additional initialization scripts...

:: Continue with your existing initialization logic
:: For example, run SQL files if they exist
if exist "C:\docker-entrypoint-initdb.d\*.sql" (
    for %%f in (C:\docker-entrypoint-initdb.d\*.sql) do (
        echo Executing %%f
        mysql -u root -p%MYSQL_ROOT_PASSWORD% vacation_planning < %%f
    )
)

echo Initialization completed
