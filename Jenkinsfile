pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOYMENT_MODE',
            choices: ['deploy', 'destroy', 'status'],
            description: 'Deploy: Start infrastructure, Destroy: Stop infrastructure, Status: Check status'
        )
        booleanParam(
            name: 'FORCE_REDEPLOY',
            defaultValue: false,
            description: 'Force redeploy infrastructure even if already running'
        )
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        REQUIRED_SERVICES = 'shared-mysql-db,kafka'
    }

    stages {
        stage('Checkout Infrastructure') {
            steps {
                checkout scm
            }
        }

        stage('Load Environment') {
            when {
                expression { params.DEPLOYMENT_MODE == 'deploy' }
            }
            steps {
                script {
                    withCredentials([file(credentialsId: 'dotenv-file', variable: 'ENV_FILE')]) {
                        sh '''
                            echo "Loading environment configuration..."
                            cp "$ENV_FILE" .env
                            chmod 644 .env
                            echo "Environment file loaded successfully"
                        '''
                    }
                }
            }
        }

        stage('Check Infrastructure Status') {
            steps {
                script {
                    env.INFRA_STATUS = checkInfrastructureStatus()
                    echo "Infrastructure Status: ${env.INFRA_STATUS}"
                }
            }
        }

        stage('Destroy Infrastructure') {
            when {
                expression { params.DEPLOYMENT_MODE == 'destroy' }
            }
            steps {
                script {
                    destroyInfrastructure()
                }
            }
        }

        stage('Deploy Infrastructure') {
            when {
                expression {
                    params.DEPLOYMENT_MODE == 'deploy' &&
                    (params.FORCE_REDEPLOY || shouldDeployInfrastructure())
                }
            }
            steps {
                script {
                    echo "Starting infrastructure deployment..."
                    def deploymentStatus = deployInfrastructureServices()
                    if (!deploymentStatus) {
                        error "Infrastructure deployment failed"
                    }
                }
            }
        }

        stage('Skip Deployment - Already Running') {
            when {
                expression {
                    params.DEPLOYMENT_MODE == 'deploy' &&
                    !params.FORCE_REDEPLOY &&
                    !shouldDeployInfrastructure()
                }
            }
            steps {
                script {
                    echo "✅ Infrastructure is already running and healthy - skipping deployment"
                    echo "Using existing infrastructure services"
                }
            }
        }

        stage('Verify Infrastructure Health') {
            when {
                expression { params.DEPLOYMENT_MODE == 'deploy' }
            }
            steps {
                script {
                    echo "Verifying infrastructure health..."
                    def healthStatus = verifyInfrastructureHealth()
                    if (!healthStatus) {
                        error "Infrastructure health check failed"
                    }
                }
            }
        }

        stage('Display Status') {
            when {
                expression { params.DEPLOYMENT_MODE == 'status' }
            }
            steps {
                script {
                    displayInfrastructureStatus()
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            script {
                echo "✅ Infrastructure pipeline completed successfully!"
                printInfrastructureSummary()
            }
        }
        failure {
            echo "❌ Infrastructure pipeline failed!"
        }
    }
}

// ========== INFRASTRUCTURE STATUS FUNCTIONS ==========

def checkInfrastructureStatus() {
    echo "Checking infrastructure status..."

    try {
        // Get all running containers
        def runningContainers = sh(
            script: "docker ps --format '{{.Names}}'",
            returnStdout: true
        ).trim()

        if (runningContainers == '') {
            return "not-running"
        }

        def containerList = runningContainers.split('\n')
        def requiredServices = env.REQUIRED_SERVICES.split(',')

        // Check if all required services are running
        def missingServices = requiredServices.findAll { !containerList.contains(it) }

        if (missingServices) {
            return "partial:missing-${missingServices.join(',')}"
        }

        // Check if services are healthy
        def healthStatus = checkServicesHealth(requiredServices)
        if (!healthStatus.healthy) {
            return "running-but-unhealthy:${healthStatus.unhealthyServices.join(',')}"
        }

        return "healthy"

    } catch (Exception e) {
        echo "Error checking infrastructure status: ${e.getMessage()}"
        return "error"
    }
}

def checkServicesHealth(services) {
    def unhealthyServices = []

    services.each { service ->
        try {
            switch(service) {
                case 'shared-mysql-db':
                    sh '''
                        set +x
                        MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD .env | cut -d '=' -f2)
                        docker exec shared-mysql-db mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" --silent
                        set -x
                    '''
                    break
                case 'kafka':
                    sh '''
                        # Check if Kafka process is running inside container
                        docker exec kafka ps aux | grep -q "[k]afka" || exit 1
                    '''
                    break
                default:
                    // For other services, just check if container is running
                    sh "docker ps | grep -q ${service}"
            }
        } catch (Exception e) {
            unhealthyServices.add(service)
        }
    }

    return [healthy: unhealthyServices.isEmpty(), unhealthyServices: unhealthyServices]
}

def shouldDeployInfrastructure() {
    def status = env.INFRA_STATUS
    echo "Current infrastructure status: ${status}"

    switch(status) {
        case 'not-running':
        case 'error':
            echo "Infrastructure not running or error detected - will deploy"
            return true

        case ~/^partial:missing-.*/:
            def missingServices = status.replace('partial:missing-', '').split(',')
            echo "Missing services: ${missingServices.join(', ')} - will deploy"
            return true

        case ~/^running-but-unhealthy:.*/:
            def unhealthyServices = status.replace('running-but-unhealthy:', '').split(',')
            echo "Unhealthy services: ${unhealthyServices.join(', ')} - will deploy"
            return true

        case 'healthy':
            echo "All services are healthy - no deployment needed"
            return false

        default:
            echo "Unknown status '${status}' - will deploy for safety"
            return true
    }
}

// ========== DEPLOYMENT FUNCTIONS ==========

def deployInfrastructureServices() {
    echo "Deploying infrastructure services..."

    try {
        // Stop only if services are running
        if (env.INFRA_STATUS != 'not-running') {
            echo "Stopping existing infrastructure services..."
            sh "docker compose -f ${env.DOCKER_COMPOSE_FILE} down || true"
        }

        // Deploy infrastructure
        sh """
            docker compose -f ${env.DOCKER_COMPOSE_FILE} --env-file .env up -d
        """

        // Wait for services to be ready
        waitForInfrastructureServices()
        return true

    } catch (Exception e) {
        echo "Infrastructure deployment failed: ${e.getMessage()}"
        return false
    }
}

def destroyInfrastructure() {
    echo "Destroying infrastructure services..."

    try {
        sh "docker compose -f ${env.DOCKER_COMPOSE_FILE} down"
        echo "✅ Infrastructure services destroyed successfully"
    } catch (Exception e) {
        echo "⚠️ Error during infrastructure destruction: ${e.getMessage()}"
    }
}

def waitForInfrastructureServices() {
    echo "Waiting for infrastructure services to be ready..."

    // Wait for MySQL
    timeout(time: 120, unit: 'SECONDS') {
        waitUntil {
            try {
                sh '''
                    set +x
                    MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD .env | cut -d '=' -f2)
                    docker exec shared-mysql-db mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" --silent
                    set -x
                '''
                echo "MySQL is ready"
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
                sh '''
                    # Check if Kafka container is running and process exists
                    if docker ps | grep kafka | grep -q "Up" && \
                       docker exec kafka ps aux | grep -q "[k]afka"; then
                        echo "Kafka is running"
                        # Additional initialization time
                        sleep 20
                        exit 0
                    else
                        exit 1
                    fi
                '''
                return true
            } catch (Exception e) {
                echo "Waiting for Kafka..."
                sleep 15
                return false
            }
        }
    }

    echo "✅ All infrastructure services are healthy!"
}

def verifyInfrastructureHealth() {
    echo "Verifying infrastructure health status..."

    try {
        def requiredServices = env.REQUIRED_SERVICES.split(',')
        def healthCheck = checkServicesHealth(requiredServices)

        if (!healthCheck.healthy) {
            error "Infrastructure health check failed for services: ${healthCheck.unhealthyServices.join(', ')}"
        }

        echo "✅ All infrastructure services are healthy"
        return true

    } catch (Exception e) {
        echo "Infrastructure health check failed: ${e.getMessage()}"
        return false
    }
}

def displayInfrastructureStatus() {
    echo "=== INFRASTRUCTURE STATUS ==="

    def status = env.INFRA_STATUS
    switch(status) {
        case 'not-running':
            echo "❌ Infrastructure: NOT RUNNING"
            echo "No infrastructure services are currently running"
            break

        case 'healthy':
            echo "✅ Infrastructure: HEALTHY"
            echo "All services are running and healthy"
            sh "docker ps --format 'table {{.Names}}\\t{{.Status}}' | grep -E '(${env.REQUIRED_SERVICES})'"
            break

        case ~/^partial:missing-.*/:
            def missing = status.replace('partial:missing-', '')
            echo "⚠️ Infrastructure: PARTIALLY RUNNING"
            echo "Missing services: ${missing}"
            sh "docker ps --format 'table {{.Names}}\\t{{.Status}}'"
            break

        case ~/^running-but-unhealthy:.*/:
            def unhealthy = status.replace('running-but-unhealthy:', '')
            echo "⚠️ Infrastructure: RUNNING BUT UNHEALTHY"
            echo "Unhealthy services: ${unhealthy}"
            sh "docker ps --format 'table {{.Names}}\\t{{.Status}}'"
            break

        default:
            echo "❓ Infrastructure: UNKNOWN STATUS"
            echo "Status: ${status}"
    }

    echo "============================="
}

def printInfrastructureSummary() {
    def summary = """
    🏗️  INFRASTRUCTURE SUMMARY
    =========================
    Mode: ${params.DEPLOYMENT_MODE.toUpperCase()}
    Status: ${env.INFRA_STATUS}
    """

    if (params.DEPLOYMENT_MODE == 'deploy') {
        if (env.SHOULD_DEPLOY_INFRA == 'true') {
            summary += "Action: ✅ Deployed successfully\n"
        } else {
            summary += "Action: ⏭️  Skipped (already running)\n"
        }
    } else if (params.DEPLOYMENT_MODE == 'destroy') {
        summary += "Action: 🗑️  Destroyed\n"
    }

    summary += """
    Services: ${env.REQUIRED_SERVICES}
    Kafka UI: http://localhost:8082
    =========================
    """

    echo summary
}