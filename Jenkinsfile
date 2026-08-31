pipeline {
    agent {
        label 'mac-docker'
    }

    environment {
        JIRA_BASE_URL = 'https://cesizenstestelin.atlassian.net'
        JIRA_PROJECT_KEY = 'CZM'
    }

    stages {
        stage('Clone applications') {
            steps {
                sh '''
                    rm -rf back-src front-src

                    git clone --branch main \
                        https://github.com/sarahtestelin/cesi-zen-back.git \
                        back-src

                    git clone --branch main \
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
                        docker compose \
                            -p cesi-zen-tools \
                            --env-file "$ENV_FILE" \
                            up -d --build --wait --wait-timeout 120 \
                            db back front
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                sh 'docker ps --filter "name=cesi-zen-"'
                sh 'curl --fail http://localhost:8081/actuator/health'
                sh 'curl --fail http://localhost:4300/'
            }
        }

        stage('Performance Test') {
            steps {
                sh '''
                    rm -f jmeter-results.jtl

                    /opt/homebrew/bin/jmeter -n \
                        -t performance/cesizen-load-test.jmx \
                        -Jhost=localhost \
                        -Jport=8081 \
                        -Jprotocol=http \
                        -Jthreads=10 \
                        -Jloops=5 \
                        -Jjmeter.save.saveservice.output_format=csv \
                        -l jmeter-results.jtl

                    if grep -q ',false,' jmeter-results.jtl; then
                        echo "Le test JMeter contient des requêtes en échec."
                        exit 1
                    fi
                '''
            }
        }
    }

    post {
        success {
            echo 'Déploiement CESIZen réussi.'
        }

        failure {
            echo 'Déploiement CESIZen en échec. Création d’un ticket Jira...'

            withCredentials([
                usernamePassword(
                    credentialsId: 'jira-api',
                    usernameVariable: 'JIRA_USER',
                    passwordVariable: 'JIRA_TOKEN'
                )
            ]) {
                sh '''
                    trap 'rm -f jira-payload.json' EXIT

                    cat > jira-payload.json <<EOF
{
  "fields": {
    "project": {
      "key": "${JIRA_PROJECT_KEY}"
    },
    "summary": "[CD DEPLOY] Échec du déploiement Jenkins #${BUILD_NUMBER}",
    "issuetype": {
      "name": "Incident"
    },
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "Le pipeline de déploiement Jenkins ${JOB_NAME} a échoué."
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "Build : #${BUILD_NUMBER}"
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "URL Jenkins : ${BUILD_URL}"
            }
          ]
        }
      ]
    }
  }
}
EOF

                    curl --silent \
                         --show-error \
                         --fail-with-body \
                         --user "$JIRA_USER:$JIRA_TOKEN" \
                         --request POST \
                         --header "Accept: application/json" \
                         --header "Content-Type: application/json" \
                         --data @jira-payload.json \
                         "${JIRA_BASE_URL}/rest/api/3/issue"
                '''
            }
        }
    }
}
