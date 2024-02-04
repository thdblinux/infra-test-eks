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

        stage('Setup Ingress-Nginx Controller') {
            steps {
                script {
                    sh 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml'
                }
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

        stage('Deploy APP Helm Chart on EKS') {
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
