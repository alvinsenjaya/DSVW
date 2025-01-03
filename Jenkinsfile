pipeline {
    agent none
    environment {
        DOCKERHUB_CREDENTIALS = credentials('DockerLogin')
        SNYK_CREDENTIALS = credentials('SnykToken')
        SONARQUBE_CREDENTIALS = credentials('SonarToken')
        DEPLOYMENT_USERNAME = 'ubuntu'     // Variable for deployment username
        DEPLOYMENT_TARGET_IP = '192.168.0.17' // Variable for deployment target IP
        SONARQUBE_SERVER_IP = '192.168.0.18'  // Variable for SonarQube server IP
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
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker pull xenjutsu/dsvw:0.1'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker rm -f dsvw'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no $DEPLOYMENT_USERNAME@$DEPLOYMENT_TARGET_IP docker run --detach --name dsvw -p 65412:65412 xenjutsu/dsvw:0.1'
                }
            }
        }
        stage('DAST Wapiti') {
            agent {
                docker {
                    image 'xenjutsu/wapiti:3.2.0'
                    args '--user root --network host --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'wapiti -u http://$DEPLOYMENT_TARGET_IP:65412 -f xml -o wapiti-report.xml'
                }
                archiveArtifacts artifacts: 'wapiti-report.xml'
            }
        }
        stage('DAST Nuclei') {
            agent {
                docker {
                    image 'projectdiscovery/nuclei'
                    args '--user root --network host --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'nuclei -u http://$DEPLOYMENT_TARGET_IP:65412 -nc -j > nuclei-report.json'
                    sh 'cat nuclei-report.json'
                }
                archiveArtifacts artifacts: 'nuclei-report.json'
            }
        }
        stage('DAST OWASP ZAP') {
            agent {
                docker {
                    image 'ghcr.io/zaproxy/zaproxy:weekly'
                    args '-u root --network host -v /var/run/docker.sock:/var/run/docker.sock --entrypoint= -v .:/zap/wrk/:rw'
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'zap-baseline.py -t http://$DEPLOYMENT_TARGET_IP:65412 -r zapbaseline.html -x zapbaseline.xml'
                }
                sh 'cp /zap/wrk/zapbaseline.html ./zapbaseline.html'
                sh 'cp /zap/wrk/zapbaseline.xml ./zapbaseline.xml'
                archiveArtifacts artifacts: 'zapbaseline.html'
                archiveArtifacts artifacts: 'zapbaseline.xml'
            }
        }
    }
    post {
        always {
            node('built-in') {
                sh 'curl -X POST http://192.168.0.20:8080/api/v2/import-scan/ -H "Authorization: Token 3a094d8299155a1a5719fcd1cfe2a63b9dda26f5" -F "scan_type=Trufflehog Scan" -F "file=@./trufflehog-scan-result.json;type=application/json" -F "engagement=3"'
                sh 'curl -X POST http://192.168.0.20:8080/api/v2/import-scan/ -H "Authorization: Token 3a094d8299155a1a5719fcd1cfe2a63b9dda26f5" -F "scan_type=Snyk Code Scan" -F "file=@./snyk-sast-report.json;type=application/json" -F "engagement=3"'
                sh 'curl -X POST http://192.168.0.20:8080/api/v2/import-scan/ -H "Authorization: Token 3a094d8299155a1a5719fcd1cfe2a63b9dda26f5" -F "scan_type=ZAP Scan" -F "file=@./zapbaseline.xml;type=text/xml" -F "engagement=3"'
            }
        }
    }
}
