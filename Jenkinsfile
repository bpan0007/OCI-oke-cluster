pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Run Script') {
            steps {
                sh './app-script.sh'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline executed successfully!'
        }
    }
}