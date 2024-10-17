pipeline {
    agent any
    environment {
        EMAIL_SOURCE = 'londhekarishma6994@gmail.com'
        EMAIL_PASSWORD = 'zwftgvcneqnsygwl'
        EMAIL_RECIPIENT = 'londhe.karishma61@gmail.com'
    }
    stages {
        stage('Install Python Libraries') {
            steps {
                script {
                    // Install required Python libraries
                    sh '''
                    pip install boto3 pandas python-dotenv
                    '''
                }
            }
        }
        stage('Run Metrics Report Script') {
            steps {
                script {
                    // Run the Python script to generate the metrics report and send email
                    sh 'python3 generate_report.py'
                }
            }
        }
    }
    triggers {
        cron('0 8 * * 1')  // Every Monday at 8 AM
    }
}
