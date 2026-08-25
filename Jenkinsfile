pipeline {
    agent {
        label 'mac-docker'
    }

    stages {
        stage('Clone applications') {
            steps {
                sh '''
                    rm -rf back-src front-src

                    git clone --branch feat/deploy-security \
                        https://github.com/sarahtestelin/cesi-zen-back.git \
                        back-src

                    git clone --branch feat/deploy-security \
                        https://github.com/sarahtestelin/cesi-zen-front.git \
                        front-src
                '''
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    file(credentialsId: 'cesizen-deploy-env', variable: 'ENV_FILE')
                ]) {
                    sh '''
                        BACK_CONTEXT="$WORKSPACE/back-src" \
                        FRONT_CONTEXT="$WORKSPACE/front-src" \
                        docker compose --env-file "$ENV_FILE" up -d --build
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                sh 'docker compose ps'
                sh 'curl --fail http://localhost:8081/actuator/health'
                sh 'curl --fail http://localhost:4300/'
            }
        }
    }

    post {
        success {
            echo 'Déploiement CESIZen réussi.'
        }

        failure {
            echo 'Déploiement CESIZen en échec.'
        }
    }
}