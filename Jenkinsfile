pipeline{
    	
	agent any
	
	tools{
		gradle 'Gradle'
	}
    	environment {
		DOCKERHUB = credentials('Dockerhub')
    	}
    
    
	stages {
        	stage('Checkout') {
                	steps {
                    	echo "Checkout the code from GitLab repo..."
                    	checkout scm
                	}
            	}     

  
            	stage('Build'){
                	//Building Docker Image
                	steps{
                		echo "Building the docker file..."
				sh 'docker build -t k8-app:latest .'
                	}   
            	}     
 
            	stage('Publishing Images to Dockerhub'){
               		//Pushing Docker images to Nexus Repo 
                	steps{
                		echo "Pushing the image created to Dockerhub..."
                		sh 'docker tag k8_app:latest pritidevops/k8_app:latest'
                		sh 'echo $DOCKERHUB_PSW | docker login -u $DOCKERHUB_USR --password-stdin'
                		sh 'docker push pritidevops/k8_app:latest'
                    	}
                }
		
        	stage('Creating namespace on k8 cluster') {
            		steps {
                		sshagent(['k8-server']) {
                    			sh 'ssh -o StrictHostKeyChecking=no devsecops1@192.168.6.77 "kubectl create ns k8-task"'
                		}
            		}
        	}
		
	       stage('Deployment'){
                	//Application deploying on Staging server

                	steps{
                    		echo "Deploy image to prod environment..."
                    		kubernetesDeploy(
                        		configs: 'k8-task.yml',
                        		kubeconfigId: 'k8-config',
                        		enableConfigSubstitution: true 
                    		)
                	}
            	}



    }//stages closing
}//pipeline closing


        
        
