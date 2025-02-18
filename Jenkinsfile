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
                sh 'python3 app-script.py'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline executed successfully!'
        }
    }
}