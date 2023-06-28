pipeline{
    agent any
    environment {
        NEXUS_URL = "http://192.168.6.99:8082"
        NEXUS_CREDENTIALS = "Nexus"
        NEXUS_REPO = "192.168.6.99:8082"
    }
    parameters {
        booleanParam(name: 'enableCleanUp', defaultValue: false, description: 'Select to clean the environements')
    }
    stages {
            stage('Checkout') {
                steps {
                    echo "Checkout the code from GitLab repo..."
                    checkout scm
                }
            }
            stage('Check if Environment exists') {
                when {
                    expression{
                        params.enableCleanUp == true
                    }
                }
                steps {
                    echo "Checking is the environments exists before starting woth cleanup..."
                    sshagent(['k8-config']){
                            sh 'ssh -o StrictHostKeyChecking=no devsecops1@192.168.6.77 "kubectl get namespace staging prod"'
                        }
                }
            }        
            stage ('Software Composition Analysis'){
                //SCA using Dependency Check tool
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps {
                	script{	
                        echo "Starting Software Composition Analysis using Dependenct Check Tool..."
 					    dependencyCheck additionalArguments: '--format XML', odcInstallation: 'SCA'
 					    dependencyCheckPublisher pattern: '' 
                    }    
                }
            }
            stage('SonarQube Analysis') {
                //Static Code Analysis using Sonarqube tool
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                environment {
                        SCANNER_HOME = tool 'SonarQubeScanner'
                    }
                
                steps {
                    echo "Starting Statis Code Analysis using Sonar Qube Tool..."
                    withSonarQubeEnv(credentialsId: 'SonarQubeScanner', installationName: 'SonarQubeScanner') {
                    sh './gradlew sonarqube \
                            -Dsonar.projectKey=TX-DevSecOps-Web \
                            -Dsonar.host.url=http://192.168.6.99:9000 \
                            -Dsonar.login=352c647b9f2293c125b4def53e74b0eb9260efcf'
                    } 
                } 
            }
            stage('Unit Testing') {
            //Unit Testing using JUnit
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo " Starting JUnit Unit tests..."
                        junit(testResults: 'build/test-results/test/*.xml', allowEmptyResults : true, skipPublishingChecks: true)
                }
                post {
                    success {
                        publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: '', reportFiles: 'index.html', reportName: 'HTML Report', reportTitles: '', useWrapperFileDirectly: true])
                    }
                }
            }   
            stage ('Docker File Scan'){
                //Dockerfile Scan using Checkov tool
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Scanning docker file using CheckOv Tool..."
                    //sh 'pip3 install checkov' 
                    //sh 'docker pull bridgecrew/checkov'
                    sh 'sudo checkov -f Dockerfile --skip-check CKV_DOCKER_3 '        //skip USER in Dockerfile with CKV_DOCKER_3
                }
            }     
            stage('Build'){
                //Building Docker Image
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Building the docker file..."
                    sshagent(['dev']){
                        sh 'ssh -o StrictHostKeyChecking=no testing@192.168.6.99 "export PATH=\$PATH:/opt/gradle/gradle-7.1.1/bin && cd /home/testing/tx-web && docker build -t devsecops . && docker tag devsecops:latest $NEXUS_REPO/devsecops:latest"'
                    }
                }   
            }     
            stage('Image Scanning') {
                //Image scanning using Trivy tool
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
		        steps{
                    echo "Scanning the docker image using Trivy tool..."
                    sshagent(['dev']){
                        sh 'ssh -o StrictHostKeyChecking=no testing@192.168.6.99 "trivy image $NEXUS_REPO/devsecops:latest"'
                    }
		        }
	        } 
            stage('Publishing Images to Nexus Registry'){
                //Pushing Docker images to Nexus Repo 
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Pushing the image created to Nexus..."
                    sshagent(['dev']){
                            sh 'ssh -o StrictHostKeyChecking=no testing@192.168.6.99 "docker push $NEXUS_REPO/devsecops:latest && docker rmi -f devsecops:latest && docker rmi -f $NEXUS_REPO/devsecops:latest"'
                        }
                    }
                }
            stage('Creating Environments'){
                // Creating namespaces for different environments on k8 cluster
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Preping staging and Production environment..."
                    sshagent(['k8-config']){
                        sh 'ssh -o StrictHostKeyChecking=no devsecops1@192.168.6.77 "kubectl create ns staging && kubectl create ns prod"'
                    }
                }   
            }
            stage('Staging Deployment'){
                //Application deploying on Staging server
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Deploy image to Staging environment..."
                    withCredentials([
                        usernamePassword(credentialsId: 'docker-registry-creds', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')
    ]) {
            sh """
                ssh -o StrictHostKeyChecking=no devsecops1@192.168.6.77 "kubectl create secret docker-registry regcred --docker-server=192.168.6.99:8082 --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD -n staging && kubectl create secret docker-registry regcred --docker-server=192.168.6.99:8082 --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD -n prod"
      """
    }
                    kubernetesDeploy(
                        configs: 'k8-staging.yml',
                        kubeconfigId: 'k8-config',
                        enableConfigSubstitution: true 
                    )
                }
            }
            stage('Web Application Scanning'){
                //Web Application scanning using ZAP        
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    echo "Performing DAST Scan on app using ZAP tool..."
                    catchError(buildResult: 'Success', stageResult: 'Success'){
                    sleep time: 30, unit: 'SECONDS'
                    sshagent(['dev'])
                    {
                        sh 'ssh -o StrictHostKeyChecking=no testing@192.168.6.99 "docker pull owasp/zap2docker-stable && docker run -t owasp/zap2docker-stable zap-baseline.py -t http://192.168.6.68:32000/VulnerableApp/ && docker rmi -f owasp/zap2docker-stable"'
                    }
                    }
                }
            }
            stage('Pre-Prod Approval'){
                //Pre-Prod Approval
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{              
                    script {
                        timeout(time: 10, unit: 'MINUTES'){
                            input ('Deploy to Production?')
                        }
                    }        
                } 
            }
            stage('Production Deployment'){
                //Application deploying on production server
                when {
                    expression{
                        params.enableCleanUp == false
                    }
                }
                steps{
                    script{
                        echo "Deploy image to Production environment..."
                        kubernetesDeploy(
                            configs: 'k8-prod.yml',
                            kubeconfigId: 'k8-config',
                            enableConfigSubstitution: true 
                        )
                    }
                }
            }
            stage('Clean Up Approval'){
                steps{              
                    script {
                        timeout(time: 10, unit: 'MINUTES'){
                            input ('Proceed with Environment CleanUp?')
                        }
                    }        
                } 
            }
            stage('Cleaning Workspace') {
                //Deleting staging and prod environments
                when {
                    expression{
                        params.enableCleanUp == true
                    }
                }
                steps{
                        sshagent(['k8-config']){
                            sh 'ssh -o StrictHostKeyChecking=no devsecops1@192.168.6.77 "kubectl delete ns staging prod"'
                        }
                }
            }
            stage('Monitoring') {
                //Monitoring Dashboard Details
                steps{
                    script{
                        echo " Monitor Deployments here: http://192.168.6.99:3000/"
                    }     
                }
            }

    }//stages closing
}//pipeline closing


        
        
