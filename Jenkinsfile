pipeline {
    agent any

    parameters {
        choice(
            name: 'TARGET_APP',
            choices: ['main-app', 'microservice-app', 'both'],
            description: 'Which application to deploy after infrastructure'
        )
    }

    environment {
        INFRA_REPO = 'https://github.com/hiiico/Infrastructure'
        MAIN_APP_REPO = 'https://github.com/hiiico/vacation_planning'
        MICROSERVICE_APP_REPO = 'https://github.com/hiiico/vacation-planning-notifications'
    }

    stages {
        stage('Checkout Infrastructure') {
            steps {
                checkout scm
            }
        }

        stage('Extract .env File') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'dotenv-file', variable: 'ENV_FILE')]) {
                        // Copy the .env file to workspace
                        sh '''
                            echo "Copying .env file..."
                            cp "$ENV_FILE" .env
                            chmod 644 .env
                            ls -la .env
                            echo ".env file loaded successfully"
                        '''
                    }
                }
            }
        }

        stage('Deploy Infrastructure') {
            steps {
                script {
                    echo "Deploying Infrastructure Services..."

                    sh '''
                        docker compose -f docker-compose.yml down || true
                        docker compose -f docker-compose.yml --env-file .env up -d
                    '''

                    // Wait for services to be healthy
                    waitForInfrastructureServices()
                }
            }
        }

        stage('Deploy Applications') {
            steps {
                script {
                    def appsToDeploy = []

                    if (params.TARGET_APP == 'both') {
                        appsToDeploy = ['main-app', 'microservice-app']
                    } else {
                        appsToDeploy = [params.TARGET_APP]
                    }

                    appsToDeploy.each { app ->
                        deployApplication(app)
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    // Verify all services are running
                    sh "docker ps --format 'table {{.Names}}\\t{{.Status}}'"
                    echo "✅ All services deployed successfully!"
                }
            }
        }
    }

    post {
        always {
            // Clean up the .env file from workspace
            sh 'rm -f .env'
            cleanWs()
        }
        success {
            echo "🚀 Deployment Completed Successfully!"
            script {
                echo "Access your applications:"
                echo "Main App: http://localhost:8080"
                echo "Notification Service: http://localhost:8081"
                echo "Kafka UI: http://localhost:8082"
            }
        }
        failure {
            echo "❌ Deployment Failed!"
            // Clean up on failure
            sh "docker compose -f docker-compose.yml down || true"
        }
    }
}

def waitForInfrastructureServices() {
    echo "Waiting for infrastructure services to be ready..."

    // Wait for MySQL
    sh '''
            set +x  # Disable command echoing for security
            MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD .env | cut -d '=' -f2)
            until docker exec shared-mysql-db mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" --silent; do
                echo "Waiting for MySQL..."
                sleep 5
            done
            set -x  # Re-enable command echoing
        '''

    // Wait for Kafka
    timeout(time: 180, unit: 'SECONDS') {
            waitUntil {
                try {
                    // Try multiple approaches to check if Kafka is ready
                    sh '''
                        # Method 1: Check if Kafka container is running and port is accessible
                        if docker ps | grep kafka | grep -q "Up"; then
                            # Method 2: Use kafka-topics command with full path
                            docker exec kafka /bin/bash -c "cd /opt/kafka && bin/kafka-topics.sh --bootstrap-server localhost:9092 --list" || true
                            # Method 3: Simple port check
                            nc -z kafka 9092 && echo "Kafka is ready"
                        else
                            exit 1
                        fi
                    '''
                    return true
                } catch (Exception e) {
                    echo "Waiting for Kafka to be ready..."
                    sleep 15
                    return false
                }
            }
        }

        echo "All infrastructure services are healthy!"
    }

    echo "✅ All infrastructure services are healthy!"
}

def deployApplication(String appName) {
    echo "Deploying ${appName}..."

    dir(appName) {
        // Checkout the application repository
        def repoUrl = appName == 'main-app' ? env.MAIN_APP_REPO : env.MICROSERVICE_APP_REPO
        checkout([
            $class: 'GitSCM',
            branches: [[name: "*/main"]],
            extensions: [],
            userRemoteConfigs: [[
                url: repoUrl,
                credentialsId: 'your-git-credentials'
            ]]
        ])

        // Copy the .env file to application directory
        sh '''
                    cp ../.env .
                    docker-compose build --no-cache
                    docker-compose down || true
                    docker-compose up -d
                '''

                // Wait for application health
                waitForApplicationHealth(appName)
    }
}

def waitForApplicationHealth(String appName) {
    def port = appName == 'main-app' ? '8080' : '8081'

    echo "Waiting for ${appName} to be healthy..."

    timeout(time: 120, unit: 'SECONDS') {
        waitUntil {
            try {
                sh "curl -f http://localhost:${port}/actuator/health"
                return true
            } catch (Exception e) {
                echo "Waiting for ${appName} at port ${port}..."
                sleep 5
                return false
            }
        }
    }

    echo "✅ ${appName} is healthy and responding!"
}