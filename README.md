# Projeto: Criação de uma Infraestrutura para Ambientes de Stage e Produção na AWS, usando EKS.

## Pré-requisitos para criar o ambiente

- Conta na AWS
- Credenciais do IAM
- AWS CLI instalado 
- Helm instalado
- Git
- Docker 
- Kubectl
- Terraform

**Step-1:** **Criando ambiente de stage**

- Clone o repositório para versionar o código do projeto:
- 
```sh
git clone https://github.com/thdevopssre/infra-test-eks.git
```

- Acesse o diretório onde estão os arquivos do Terraform para criar o cluster EKS de stage.
- 
```sh
cd /terraform/stg
```
- Agora no diretorio do arquivos do Terraform vamos usar os comando para cria o cluster.

```sh
terraform init
```
```sh
terraform fmt
```
```sh
terraform validate
```
```sh
terraform plan
```
```sh
terraform apply -auto-approve
```
- OBS: Use o comando `terraform apply -auto-approve` apenas se você tiver certeza de que todos os recursos mostrados no terraform `plan` são os necessários para sua infraestrutura. Caso contrário, use apenas o comando `terraform apply` sem` -auto-auto-approve`. Ele mostrará todo o plano da sua infraestrutura e solicitará confirmação para executar o comando.` yes` ou` no`

Use um comando da `AWS` para interagir com o cluster via `CLI` usando o `kubectl` e também criar e atualizar o arquivo` kubeconfig`:

- Usaremos um comando da AWS para fazer interação com o cluster via `CLI `usando o `kubectl` e tammbé irar cria e atualizar o arquivo `kubeconfig:`
  
```sh
aws eks update-kubeconfig --region region-code --name my-cluster
``` 

**Step-2:** **Configurando O  Ingress-Nginx Controller e o cert-manager**

Como vamos expor a nossa aplicação para fora do cluste usaremos um `dominio` e um servidro web chamado `Nginx` ele ira garantir que a nossa aplicaç~ao funcione dentro do cluster de maneira segura e eficiente. O `Ingress-Nginx Controller` atua como um componente crucial para gerenciar o roteamento de tráfego externo para os serviços internos do cluster `Kubernetes`.

Além disso, para garantir uma comunicação segura e estabelecer uma conexão `HTTPS `confiável, utilizaremos o` Cert-Manager`. O Cert-Manager é uma ferramenta especializada em automatizar a emissão e renovação de certificados` TLS,` essenciais para garantir a `segurança` da transmissão de dados entre o servidor` web Nginx` e os usuários finais.

Ao implementar essas soluções em conjunto, o `Ingress-Nginx Controller`e o `Cert-Manager `proporcionam uma infraestrutura robusta para a exposição segura da nossa aplicação. O `Ingress-Nginx `direciona o `tráfego externo `para os serviços internos, enquanto o `Cert-Manager `automatiza a gestão dos certificados` TLS`, garantindo a `integridade` e `segurança `das comunicações.

- Instalando um Ingress Controller Vamos continuar usando o Nginx Ingress Controller como exemplo, que é amplamente adotado e bem documentado.
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
```
-  
Agora, vamos criar um certificado para nossa aplicação usando o arquivo de configuração fornecido pelo Cert-Manager.
  
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: marciothadeu1984@gmail.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```
OBS:: Nos ambientes de Produção, não declaramos "staging" dentro do endereço do servidor https. Os arquivos de configuração do cert-manager e o comando para instalar o Nginx Ingress Controller podem ser declarados na pipeline.O cert-manager pode ser usado junto aos aqruivos de configuração do Helm. 


**Step-3:** **Criando o CI com Jenkins**

Com o nosso cluster provisionado, agora podemos focar na criação da Pipeline. Usaremos o Jenkins como ferramenta de CI para realizar a integração com o cluster e com a nossa aplicação.

Instale o Jenkins em um namespace do cluster EKS seguindo este tutorial na Documentação do Jenkins: 
https://www.jenkins.io/doc/book/installing/kubernetes/

**Instale ferramentas Docker e plug-ins Docker:**

- Docker
- Docker Commons
- Docker Pipeline
- Docker API
- docker-build-step
- kubernetes
- kubernetes cli

Configure as credenciais do Docker e do kubeconfig para permitir que o Jenkins interaja com a pipeline.

1. **Credenciais do Docker:**
- Certifique-se de ter o Docker instalado em seu ambiente Jenkins.
- Acesse o Jenkins e vá para o painel de administração.
- No painel de administração, clique em "Credenciais" e, em seguida, "Sistema".
-  Adicione uma nova credencial, escolhendo o tipo apropriado para as credenciais do Docker (por exemplo, "Nome de usuário e senha" ou "Token de acesso").
-  Forneça as informações necessárias, como nome de usuário, senha ou token, e salve as credenciais.
  
2.**kubeconfig:**
- Garanta que o kubectl (cliente Kubernetes) esteja instalado no ambiente Jenkins.
- No Jenkins, vá para o painel de administração e clique em "Credenciais" e, em seguida, "Sistema".
- Adicione uma nova credencial, escolhendo o tipo "Arquivo de texto secreto".
- Copie o conteúdo do seu arquivo kubeconfig para o campo de texto ou faça upload do arquivo diretamente.
- Salve as credenciais.

3.Configuração na Pipeline:

- Abra ou crie o arquivo Jenkinsfile da sua pipeline.
- Adicione etapas para configurar as credenciais recém-criadas.
- Certifique-se de substituir 'seu-id-de-credencial-docker' e 'seu-id-de-credencial-kubeconfig' pelos IDs reais das credenciais criadas anteriormente.
- 

```yaml
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
                    dir('./Helm_charts/descoshop') {
                        sh "helm install descoshop ./descoshop"
                    }
                }
            }
        }
    }
}
```
**Step-3:** **Deploy da Aplicação com ArgoCD**

1.Instale o ArgoCD:

Todos esses componentes podem ser instalados usando um manifesto fornecido pelo Projeto Argo:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
```
2.Expose argocd-server

```sh
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```
```sh
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```
3.Login

```sh
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```
```sh
export ARGOCD_SERVER=`kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
```

```sh
echo $ARGOCD_SERVER
```

```sh
echo $ARGO_PWD
```
5.Defina seu repositório GitHub como fonte:

Depois de instalar o ArgoCD, você precisa configurar seu repositório GitHub como fonte para a implantação do seu aplicativo. Isso normalmente envolve configurar a conexão com o seu repositório e definir a fonte do seu aplicativo ArgoCD. As etapas específicas dependerão de sua configuração e requisitos.

6.Crie um aplicativo ArgoCD:

- `name`:Defina o nome do seu aplicativo.
- `destination`: Defina o destino onde seu aplicativo deve ser implantado.
- `project`: Especifique o projeto ao qual o aplicativo pertence.
- `source`: defina a origem do seu aplicativo, incluindo a URL do repositório GitHub, a revisão e o caminho para o aplicativo dentro do repositório.
- `syncPolicy`: Configure a política de sincronização, incluindo sincronização automática, remoção e autocorreção.

PS: Se tudo ocorrer perfeitamente bem no ambiente de `stage,` agora podemos repetir o mesmo processo para construir o ambiente de `produção`.


**Step-4:** **Removendo o ambiente de stage**
 No diretorio do arquivos de configuração do Terraform aplique o comando:

 ```sh
 terraform destroy
 ``` 
 Este comando irá remover todos os recursos que foram provisionados na AWS, garantindo que você não seja cobrado por nada.

 ## Resumo do Projeto 

**Descrição**

Este projeto visa configurar a infraestrutura para a aplicação "descoshop", que será implantada em dois ambientes: teste e produção, utilizando clusters Kubernetes. A entrega do projeto envolve a criação de arquivos de configuração, configuração de fluxo de integração contínua e implementação de recursos AWS.

**Ambiente**
- Ambiente de Testes:` descoshop.stg.descomplica.com.br`
- Database: `descoshop-stg.rds.aws.amazon.com`
- Pods: 1 a 4, CPU/Memory: request 200m/192Mi, limit 400m/512Mi
- Variáveis de Ambiente: GOOGLE_RECAPTCHA_URL, ENABLE_RECAPTCHA, BUCKET_NFE
- Ambiente de Produção: `descoshop.descomplica.com.br`
- Database: `descoshop-prd.rds.aws.amazon.com`
- Pods: 4 a 10, CPU/Memory: request 200m/192Mi, limit 400m/512Mi
- Variáveis de Ambiente: GOOGLE_RECAPTCHA_URL, ENABLE_RECAPTCHA, BUCKET_NFE

**Segurança:**

As informações de conexão ao banco de dados devem ser protegidas usando recursos seguros do Kubernetes. Um bucket S3 privado será criado para armazenar notas fiscais eletrônicas, com regras de acesso definidas.

**Entregáveis:**

-  Arquivos Terraform para configurar o bucket S3.
- Configurações da pipeline CI/CD Jenkins.
- Arquivos de configuração da aplicação no Kubernetes (Helm templates, values, etc.).
- Documentação detalhada dos passos executados.

**Tecnologias Utilizadas:**

Kubernetes, Docker, Terraform, Helm, GitHub, CI/CD,Argocd, e recursos AWS.

## Links úteis para a documentação das tecnologias utilizadas no projeto:

- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Docker Builder Reference](https://docs.docker.com/engine/reference/builder/)
- [Docker Postgres Sample](https://docs.docker.com/samples/postgres/)
- [Docker Postgres Image](https://hub.docker.com/_/postgres)
- [Terraform AWS Provider Workspace Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/workspaces_workspace)
- [Terraform AWS Getting Started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-variables)
- [Terraform AWS Resource Tagging Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging)
- [Helm Installation Guide](https://helm.sh/docs/intro/install/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/2.15.0)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform AWS S3 Bucket Module](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)
- [Terraform Configuration Language Guide](https://developer.hashicorp.com/terraform/tutorials/configuration-language/variables)
- [Terraform Language Values and Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Go Development Use Cases](https://go.dev/solutions/use-cases)
- [Kubernetes Nginx Ingress Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/)
- [Artifact Hub](https://artifacthub.io/)
- [EKS Workshop](https://archive.eksworkshop.com/intermediate/290_argocd/install/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [GitHub Repository](https://github.com/)
- [Cert-Manager](https://cert-manager.io/)



