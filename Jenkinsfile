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
                        sh "cp $ENV_FILE .env"
                        sh "chmod 644 .env"  // Ensure proper permissions

                        // Display that .env was loaded (without showing secrets)
                        echo "✅ .env file loaded successfully"
                        sh "ls -la .env"
                    }
                }
            }
        }

        stage('Deploy Infrastructure') {
            steps {
                script {
                    echo "Deploying Infrastructure Services..."

                    // Stop existing infrastructure if running
                    sh "docker compose -f docker-compose.yml down || true"

                    // Deploy infrastructure with the .env file
                    sh "docker compose -f docker-compose.yml --env-file .env up -d"

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

    // Load environment variables from .env file for health checks
    def envVars = readProperties file: '.env'

    // Wait for MySQL
    timeout(time: 120, unit: 'SECONDS') {
        waitUntil {
            try {
                sh "docker exec shared-mysql-db mysqladmin ping -u root -p${envVars['MYSQL_ROOT_PASSWORD']} --silent"
                return true
            } catch (Exception e) {
                echo "Waiting for MySQL..."
                sleep 5
                return false
            }
        }
    }

    // Wait for Kafka
    timeout(time: 180, unit: 'SECONDS') {
        waitUntil {
            try {
                sh "docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list"
                return true
            } catch (Exception e) {
                echo "Waiting for Kafka..."
                sleep 10
                return false
            }
        }
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
        sh "cp ../.env ."

        // Build and deploy application
        sh "docker compose build --no-cache"
        sh "docker compose down || true"
        sh "docker compose up -d"

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