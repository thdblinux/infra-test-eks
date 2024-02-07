pipeline {
    agent any
    tools {
        go '1.19'
    }

    stages {
        stage('Clean workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/thdevopssre/infra-test-eks'
            }
        }

        stage("Docker Build & Push") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker', toolName: 'docker') {
                        dockerapp = docker.build("thsre/descoshop:${env.BUILD_ID}", '-f ./frontend/Dockerfile .')
                        docker.withRegistry('https://registry.hub.docker.com', 'docker') {
                            dockerapp.push('latest')
                            dockerapp.push("${env.BUILD_ID}")
                        }
                    }
                }
            }
        }

        stage('Deploy DB Helm Chart on EKS') {
            steps {
                script {
                    sh ('aws eks update-kubeconfig --name matrix-stg --region us-east-1')
                    sh "kubectl get ns"
                    dir('./infra-test-eks') {
                        sh "helm install infra-test-eks ./descoshop"
                    }
                }
            }
        }
    }
}
