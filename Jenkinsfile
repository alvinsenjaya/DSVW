pipeline {
    agent none
    environment {
        DOCKERHUB_CREDENTIALS = credentials('DockerLogin')
        SNYK_CREDENTIALS = credentials('SnykToken')
        SONARQUBE_CREDENTIALS = credentials('SonarToken')
        DEPLOYMENT_USERNAME = 'jtf01645'     // Variable for deployment username
        DEPLOYMENT_TARGET_IP = '192.168.1.19' // Variable for deployment target IP
        SONARQUBE_SERVER_IP = '192.168.1.19'  // Variable for SonarQube server IP
    }
    stages {
        stage('Secret Scanning Using Trufflehog') {
            agent {
                docker {
                    image 'trufflesecurity/trufflehog:latest'
                    args '--entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'trufflehog filesystem . --fail --json --no-update > trufflehog-scan-result.json'
                }
                sh 'cat trufflehog-scan-result.json'
                archiveArtifacts artifacts: 'trufflehog-scan-result.json'
            }
        }
        stage('SCA Snyk Test') {
            agent {
                docker {
                    image 'snyk/snyk:node'
                    args '-u root --network host --env SNYK_TOKEN=$SNYK_CREDENTIALS_PSW --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'snyk test --json > snyk-scan-report.json'
                }
                sh 'cat snyk-scan-report.json'
                archiveArtifacts artifacts: 'snyk-scan-report.json'
            }
        }
        stage('SCA Retire Js') {
            agent {
                docker {
                    image 'node:lts-buster-slim'
                }
            }
            steps {
                sh 'npm install retire'
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh './node_modules/retire/lib/cli.js --outputformat json --outputpath retire-scan-report.json'
                }
                sh 'cat retire-scan-report.json'
                archiveArtifacts artifacts: 'retire-scan-report.json'
            }
        }
        stage('SCA Trivy Scan Dockerfile Misconfiguration') {
            agent {
                docker {
                    image 'aquasec/trivy:latest'
                    args '-u root --network host --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'trivy config Dockerfile --exit-code=1 --format json > trivy-scan-dockerfile-report.json'
                }
                sh 'cat trivy-scan-dockerfile-report.json'
                archiveArtifacts artifacts: 'trivy-scan-dockerfile-report.json'
            }
        }
        stage('SAST Snyk') {
            agent {
                docker {
                    image 'snyk/snyk:node'
                    args '-u root --network host --env SNYK_TOKEN=$SNYK_CREDENTIALS_PSW --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'snyk code test --json > snyk-sast-report.json'
                }
                sh 'cat snyk-sast-report.json'
                archiveArtifacts artifacts: 'snyk-sast-report.json'
            }
        }
        stage('SAST SonarQube') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    args '--network host -v ".:/usr/src" --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "sonar-scanner -Dsonar.projectKey=dsvw -Dsonar.qualitygate.wait=true -Dsonar.sources=. -Dsonar.host.url=http://$SONARQUBE_SERVER_IP:9000 -Dsonar.token=$SONARQUBE_CREDENTIALS_PSW"
                }
            }
        }
        stage('Build Docker Image and Push to Docker Registry') {
            agent {
                docker {
                    image 'docker:dind'
                    args '--user root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                sh 'docker build -t xenjutsu/dsvw:0.1 .'
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh 'docker push xenjutsu/dsvw:0.1'
            }
        }
        stage('Deploy Docker Image') {
            agent {
                docker {
                    image 'kroniak/ssh-client'
                    args '--user root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "DeploymentSSHKey", keyFileVariable: 'keyfile')]) {
                    sh "ssh -i \${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP 'echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin'"
                    sh "ssh -i \${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker pull xenjutsu/dsvw:0.1"
                    sh "ssh -i \${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker rm --force dsvw"
                    sh "ssh -i \${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker run -it --detach --name dsvw --network host xenjutsu/dsvw:0.1"
                }
            }
        }
    }
}
