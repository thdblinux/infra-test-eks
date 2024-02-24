# Projeto: Criação de uma Infraestrutura para Ambientes de Stage e Produção na AWS, usando EKS.
![project-infra](https://github.com/thdevopssre/infra-test-eks/assets/151967060/d59c6d8b-cd97-4a63-ad24-20b6a2f41034)


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
  
```sh
git clone https://github.com/thdevopssre/infra-test-eks.git
```

- Acesse o diretório onde estão os arquivos do Terraform para criar o cluster EKS de stage.
- 
```sh
cd /EKS/stg
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

-"Utilizaremos um comando da` AWS` para interagir com o cluster por meio da `CLI`, utilizando o` kubectl`, e também para criar e atualizar o arquivo` kubeconfig`."
- 
Lembre-se de substituir `NOME_DO_CLUSTER` e `SUA_REGIAO_AWS` pelos valores específicos do seu ambiente `AWS EKS.` Certifique-se de revisar a documentação para obter informações mais detalhadas e ajustar conforme necessário para atender aos requisitos específicos do seu ambiente.
  
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
1.**Instalar o Ingress-Nginx Controller com Helm**
   
É recomendado que no ambiente de produção o Ingress-Nginx Controller seja instalado com Helm se estiver usando algum provedor de Nuvem.

Utilize o seguinte comando Helm para instalar o Ingress-Nginx Controller no namespace ingress-nginx:

```sh
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Este comando instalará o controlador Ingress-Nginx no namespace ingress-nginx e criará o namespace se ele ainda não existir.
Este comando é idempotente, o que significa que ele instalará o controlador se ainda não estiver instalado ou o atualizará se já estiver instalado.

2.**Verificar a instalação:**

```sh
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```
Isso garante que o controlador esteja pronto e em execução antes de prosseguir.

1. **Configurar o Firewall:**

Certifique-se de configurar o firewall para permitir o tráfego nas portas necessárias. O controlador Ingress-Nginx geralmente requer as portas 80 e 443 abertas.

Para ver quais portas estão sendo usadas, execute:

```sh
kubectl -n ingress-nginx get pod -o yaml
```
Em geral, é necessário abrir a Porta 8443 entre todos os hosts nos quais os nós do Kubernetes estão em execução, usada para o controlador de admissão Ingress-Nginx.

1. **Testar os templates Helm localmente usando o Kind:**

Crie um aqruivo com om nome `kind-config.yaml`:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
```
Use o comando kubectl para criar o cluster com 1 node:

```sh
kind create cluster --name kind-multinodes --config kind-config.yaml  
```

Agora instale o ingress-nginix-controller:

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

```sh
kubectl create namespace nginx  
```

```sh
 helm install nginx ingress-nginx/ingress-nginx --namespace nginx
```

```sh
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

Agora, você pode acessar a sua aplicação localmente usando` http://localhost:8080`.


### Agora, vamos criar um certificado para nossa aplicação usando o arquivo de configuração fornecido pelo Cert-Manager crie um arquivo com o nome cert-manager.ymal e siga os comandos abixo:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: 
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```
1. Certifique-se de que os CRDs necessários estão instalados. Você pode fazer isso aplicando os arquivos CRD fornecidos pelo Cert Manager. Por exemplo:

```sh
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.0/cert-manager.crds.yaml
```
- Certifique-se de que o arquivo cert-manager-stg.yaml refere-se a um 
- ClusterIssuer válido na versão correta. Verifique se a definição do 
- ClusterIssuer está correta no arquivo cert-manager-stg.yaml.

2. Execute o comando para aplicar as configurações ao seu cluster Kubernetes:
```sh
kubectl apply -f cert-manager-stg.yaml
```

3. Verifique se o certificado foi criado:
```sh
kubectl get clusterissuers letsencrypt-staging
```

OBS:: Nos ambientes de Produção, não declaramos "staging" dentro do endereço do servidor https. Os arquivos de configuração do cert-manager e o comando para instalar o Nginx Ingress Controller podem ser declarados na pipeline.O cert-manager pode ser usado junto aos aqruivos de configuração do Helm.

**Instalação PostgreSQL com Helm no cluster Kind**

- Navegue para o diretorio onde esta a pasta contendo os arquivos helm e execute os seguintes comandos:

1.Instalar um release:
```sh
helm install go-stg ./descoshop
```

2.Listar as releases:
```sh
helm list
```
3.Verificar o Status do release:
```sh
 helm status <nome da release>
```

4.Verificar o pod associado a release:

```sh
kubectl get pods
```

```sh
kubectl exec -it <nome-do-pod> -- env
```

### Para testar a conexão com o banco de dados PostgreSQL, acessar o shell e criar uma tabela usando kubectl exec, você pode seguir os seguintes passos:

1. Obter o nome do pod PostgreSQL

```sh
kubectl get pods
```
Anote o nome do pod que corresponde ao PostgreSQL, por exemplo, kube-news-postgre-6876f6bf75-9nxm9

2.cessar o shell do PostgreSQL

Use o comando kubectl exec para acessar o shell do PostgreSQL:

```sh
kubectl exec -it postgre-6876f6bf75-9nxm9 -- psql -U descoshop -d descoshop-stg
```

Passo 1: Obter o nome do pod PostgreSQL

Use o seguinte comando para listar os pods em execução no seu cluster e encontre o nome do pod PostgreSQL:
```sh
kubectl get pods
```
Anote o nome do pod que corresponde ao PostgreSQL, por exemplo, postgre-6876f6bf75-9nxm9.

Passo 2: Acessar o shell do PostgreSQL

Use o comando kubectl exec para acessar o shell do PostgreSQL:

```sh
kubectl exec -it postgre-6876f6bf75-9nxm9 -- psql -U postgres-prod -d descoshop
```
Isso abrirá o shell interativo do PostgreSQL para o banco de dados descoshop-stg usando o usuário descoshop.

1. Criar a tabela
Dentro do shell do PostgreSQL, execute os comandos SQL para criar a tabela:

```sh
CREATE TABLE config (
    id SERIAL PRIMARY KEY,
    key VARCHAR(50) NOT NULL,
    value VARCHAR(255) NOT NULL
);

INSERT INTO config (key, value) VALUES
    ('POSTGRES_DB', 'descoshop-prod'),
    ('POSTGRES_USER', 'descoshop'),
    ('POSTGRES_PASSWORD', 'tonystark@123'),
    ('GOOGLE_RECAPTCHA_URL', 'https://google.com/recaptcha/api'),
    ('ENABLE_RECAPTCHA', 'true'),
    ('BUCKET_NFE', 'https://s3.console.aws.amazon.com/s3/home?region=us-east-1#');
```

Isso criará a tabela `config` e inserirá os dados fornecidos.

1. Verificar a tabela
```sh
SELECT * FROM config;
```

**Step-4:Criando o CI com O Github Actions**

Com o nosso cluster provisionado, agora podemos focar na criação da Pipeline. Usaremos o Github Actions como ferramenta de CI para realizar a integração com o cluster e com a nossa aplicação.

- configure as secrets e variables do cloud provider e do registry da imagem Docker no Actions do Github.
- Settings => actions => Secrets and variables => Actions => New repository secret
  

Com o nosso cluster provisionado, agora podemos focar na criação da Pipeline. Usaremos o Github Actions como ferramenta de CI para realizar a integração com o cluster e com a nossa aplicação.


Configure as credenciais do Docker e do EKS para permitir que o Github Actions interaja com a pipeline.
 
 ```yaml
name: Build and push Docker image to Docker registry

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install kubectl
        uses: azure/setup-kubectl@v2.0
        with:
          version: 'v1.29.0'
        id: install

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Docker build and push
        run: |
          docker build -t node-app .
          docker tag node-app thsre/node-app:latest
          docker login -u ${{ secrets.DOCKERHUB_USERNAME }} -p ${{ secrets.DOCKERHUB_TOKEN }}
          docker push thsre/node-app:latest
        env:
          DOCKER_CLI_ACI: 1

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name matrix-prod --region us-east-1

      - name: Deploy nodejs Helm chart to EKS
        run: |
          helm install descoshop ./go-prod
          helm install postgresql ./postgres-prod
 ```

**Step-3:** **Deploy da Aplicação com ArgoCD**

Instale o ArgoCD:

Todos esses componentes podem ser instalados usando um manifesto fornecido pelo Projeto Argo:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
```

```sh
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```


```sh
export ARGOCD_SERVER=`kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
```

```sh
export ARGO_PWD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
```

```sh
echo $ARGOCD_SERVER
```

```sh
echo $ARGO_PWD
```
- Defina seu repositório GitHub como fonte no Argocd:

Depois de instalar o ArgoCD, você precisa configurar seu repositório GitHub como fonte para a implantação do seu aplicativo. Isso normalmente envolve configurar a conexão com o seu repositório e definir a fonte do seu aplicativo ArgoCD. As etapas específicas dependerão de sua configuração e requisitos.

- Crie um aplicativo ArgoCD:

- `name`:Defina o nome do seu aplicativo.
- `destination`: Defina o destino onde seu aplicativo deve ser implantado.
- `project`: Especifique o projeto ao qual o aplicativo pertence.
- `source`: defina a origem do seu aplicativo, incluindo a URL do repositório GitHub, a revisão e o caminho para o aplicativo dentro do repositório.
- `syncPolicy`: Configure a política de sincronização, incluindo sincronização automática, remoção e autocorreção.
  
  <br>
`app`
![app](https://github.com/thdevopssre/infra-test-eks/assets/151967060/7c7ce167-6a39-49bb-9d64-aa7f00117e41)

<br>

`postgresql`
![postgresql](https://github.com/thdevopssre/infra-test-eks/assets/151967060/42197f80-2cb1-4656-9b88-53a4635e7c0f)


PS: Se tudo ocorrer perfeitamente bem no ambiente de `stage,` agora podemos repetir o mesmo processo para construir o ambiente de `produção`.


**Step-4:** **Removendo o ambiente de stage ou proução**
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

- Arquivos Terraform para configurar o EKS,VPC, bucket S3.
- Configurações da pipeline CI/CD Github Actions.
- Arquivos de configuração da aplicação no Kubernetes (Helm templates, values, deployment, service. ingress ).
- Documentação detalhada dos passos executados.

**Tecnologias Utilizadas:**

Kubernetes, Docker, Terraform, Helm, Git && GitHub Actions CI, CD Argocd, e recursos AWS.

## Links úteis para a documentação das tecnologias utilizadas no projeto:

- [Docker Builder Reference](https://docs.docker.com/engine/reference/builder/)
- [Docker Postgres Sample](https://docs.docker.com/samples/postgres/)
- [Docker Postgres Image](https://hub.docker.com/_/postgres)
- [Terraform AWS Provider Workspace Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/workspaces_workspace)
- [Terraform AWS Getting Started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-variables)
- [Terraform AWS Resource Tagging Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging)
- [Helm Docs](https://helm.sh/docs/intro/install/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/2.15.0)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform AWS S3 Bucket Module](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)
- [Terraform Configuration Language Guide](https://developer.hashicorp.com/terraform/tutorials/configuration-language/variables)
- [Terraform Language Values and Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Go Development Use Cases](https://go.dev/solutions/use-cases)
- [Kubernetes Nginx Ingress Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/)
- [Artifact Hub](https://artifacthub.io/)
- [EKS Workshop Install Argocd](https://archive.eksworkshop.com/intermediate/290_argocd/install/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Cert-Manager](https://cert-manager.io/)
- [PostgreSQL Commands and Language](https://halleyoliv.gitlab.io/pgdocptbr/dml-insert.html)
- [Terragen s3-lifecycle](https://registry.terraform.io/providers/hashicorp/aws/4.2.0/docs/resources/s3_bucket_lifecycle_configuration/)
- [Amazon S3 Lifecycle configuration rule](https://repost.aws/knowledge-center/s3-multipart-cleanup-lifecycle-rule)
- [Amazon S3 modules](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)
- [AWS update kubeconfig](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)


## Para saber mais sobre Kubernetes, containers e instalações de componentes em outros sistemas operacionais, consulte o Livro Gratuito Descomplicando o Kubernetes.

[Descomplicando o Kubernetes - Livro Gratuito](https://livro.descomplicandokubernetes.com.br/?utm_medium=social&utm_source=linktree&utm_campaign=livro+descomplicando+o+kubernetes+gratuito)

[Descomplicando o Docker - Livro Gratuito](https://livro.descomplicandodocker.com.br/chapters/chapter_01.html)


# Postmortem SLA, SLO, SLI e Erro Budget

Link para meus artigos sobre SRE e DevOps [Medium](https://medium.com/@marciothadeu1984/sre-engenharia-de-confiabilidade-sla-slo-sli-e-erro-budget-entendendo-a-import%C3%A2ncia-e-6ef1d732fb53)
