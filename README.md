# AWS Infrastructure as Code — Terraform & Terragrunt

Projeto de infraestrutura AWS desenvolvido com **Terraform** e **Terragrunt**, com o objetivo de praticar Infrastructure as Code (IaC), modularização, gerenciamento de estado remoto, IAM, Kubernetes/EKS e integração com pipelines CI/CD.

## 🏗️ Arquitetura

A infraestrutura é composta pelos seguintes serviços AWS:

* **VPC**

  * Public Subnets
  * Private Subnets
  * Availability Zones
* **Amazon EKS**

  * EKS Control Plane
  * Managed Node Group
  * IAM Roles
* **Amazon ECR**

  * Container repositories
  * Integração com GitHub Actions
* **Amazon RDS PostgreSQL**
* **Amazon ElastiCache for Redis**
* **Amazon DynamoDB**
* **Amazon SQS**
* **IAM**

  * EKS Cluster Role
  * EKS Node Role
  * GitHub Actions OIDC
  * ECR permissions

Arquitetura simplificada:

```text
                              AWS
                               │
                    ┌──────────┴──────────┐
                    │         VPC          │
                    │                      │
              ┌─────┴─────┐          ┌────┴─────┐
              │   Public   │          │ Private  │
              │  Subnets   │          │ Subnets  │
              └────────────┘          └────┬─────┘
                                           │
                         ┌─────────────────┼─────────────────┐
                         │                 │                 │
                         ▼                 ▼                 ▼
                       EKS               RDS            ElastiCache
                         │
                    Node Group
                         │
                       Pods
                         │
                    ┌────┴────┐
                    ▼         ▼
                  SQS      DynamoDB


              GitHub Actions
                    │
                   OIDC
                    │
                    ▼
                IAM Role
                    │
                    ▼
                   ECR
                    │
                    ▼
              Docker Images
```

---

# 📁 Estrutura do projeto

O projeto utiliza módulos Terraform para separar as responsabilidades da infraestrutura.

```text
.
├── env/
│   └── dev/
│       └── terragrunt.hcl
│
└── modules/
    └── root/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        │
        ├── vpc/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── eks/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── ecr/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── rds/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── elasticache/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── dynamodb/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        ├── sqs/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

# 🚀 Pré-requisitos

Antes de executar o projeto, instale:

* AWS CLI
* Terraform
* Terragrunt
* Git
* Docker

Configure suas credenciais AWS:

```bash
aws configure
```

Valide o acesso:

```bash
aws sts get-caller-identity
```

Verifique também a região:

```bash
aws configure get region
```
---

# 💾 Remote State

O Terraform utiliza um **Amazon S3 Bucket** para armazenamento remoto do `terraform.tfstate`. 

*Antes de subir o ambiente crie o bucket S3 para remote state.*

O bucket possui:

* Versionamento habilitado
* Server-Side Encryption
* Estado compartilhado entre execuções do Terraform/Terragrunt

Exemplo:

```hcl
remote_state {
  backend = "s3"

  config = {
    bucket       = "challenge3-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

O `use_lockfile` é utilizado para evitar execuções simultâneas do Terraform utilizando o mesmo state.

> Para ambientes reais, o bucket de state deve possuir controles adicionais de segurança, como bloqueio de acesso público e políticas IAM restritivas.


Para criar o remote state entre no diretório do do modulo de backend:

```bash
cd modules/backend
```

Inicialize o terraform:

```bash
terraform init
```

Crie o bucket S3 com:

```bash
terraform apply -auto-approve
```

---

# ⚙️ Deploy

Entre no diretório do ambiente:

```bash
cd env/dev
```

Inicialize o Terragrunt:

```bash
terragrunt init
```

Valide a configuração:

```bash
terragrunt validate
```

Visualize o plano:

```bash
terragrunt plan
```

Aplique a infraestrutura:

```bash
terragrunt apply
```

Para destruir o ambiente:

```bash
terragrunt destroy
```

> O `destroy` deve ser utilizado com cuidado, principalmente porque recursos como RDS, ECR e o próprio state podem conter dados importantes.


# ⚙️ CI/CD

### Pipeline Terraform-CI
* Usando a o workflow no Actions: *terraform-CI*, é possivel fazer a validação do projeto terraform e sua estrutura. Basta passar a branch MAIN, o ARN da role e OIDC Provider da conta AWS, exemplo:
```bash
AWS_ROLE_ARN
arn:aws:iam::...:role/github...

AWS_OIDC_PROVIDER_ARN
arn:aws:iam::...:oidc-provider/...
```

### Pipeline Terraform-CD
* Usando a o workflow no Actions: *terraform-CD*, é possivel realizar o deploy da infrastrutura, criando cada recurso e role IAM necesárias para o projeto toggle-master. Basta passar a branch MAIN, o ARN da role e OIDC Provider da conta AWS, exemplo:
```bash
AWS_ROLE_ARN
arn:aws:iam::...:role/github...

AWS_OIDC_PROVIDER_ARN
arn:aws:iam::...:oidc-provider/...
```
