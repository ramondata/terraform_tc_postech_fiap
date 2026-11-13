# Conta pessoal — 172346499417

Ambiente independente do Academy. Nao utiliza LabRole, os modulos root-iam/root
antigos, nem o bucket/state antigo. Execute no CloudShell us-east-2 usando a
mesma role que criara e administrara o EKS. Provider e script rejeitam outra
conta para evitar aplicar na conta errada.

O padrao deste ambiente e Ohio (`us-east-2`), a regiao selecionada no projeto
Free desta conta. Bucket, provider, consultas e kubeconfig usam a mesma regiao.
O script tambem aceita `PERSONAL_REGION`, se a regiao permitida mudar.

## Criar o plano

Na raiz deste repositorio, no AWS CloudShell Linux x86_64, instale as ferramentas
uma vez por ambiente (sem sudo, downloads oficiais e verificacao de checksum):

```bash
bash scripts/install-tools.sh
```

O instalador usa Terraform 1.17.2 e Terragrunt 1.2.2, as mesmas versoes do CI.
O personal.sh adiciona ~/.local/bin ao PATH. Depois execute:

```bash
git pull --ff-only
bash scripts/personal.sh plan
```

Este comando prepara **somente o bucket S3 do state** antes do plano. Ele tem
bloqueio de acesso publico, criptografia e versionamento. O state usa lockfile S3.
EKS, EC2, NAT Gateway, bancos e cache ainda nao sao criados nesta etapa.

O script gera uma senha forte em
`$HOME/.toggle-personal/172346499417/us-east-2/rds-password`, com acesso somente do usuario,
e a passa ao Terraform por variavel de ambiente. Nao ha senha no Git nem no
stdout. O plano salvo tambem e privado, fora do checkout, pois contem dados
sensíveis. Mantenha o arquivo de senha e os dados do state para futuras operacoes.

Se ja existe state remoto, o script confere/recupera a senha e as versoes
salvas nesse state antes do plano. Isso evita gerar uma nova senha RDS ao mudar
de sessao CloudShell. Os arquivos continuam privados; nenhuma senha e impressa.
Se houver divergencia entre arquivo local e state, o comando interrompe para revisao.

Na primeira execucao ele consulta versoes realmente disponiveis na regiao:
prefere EKS 1.36 se estiver em suporte padrao; caso contrario escolhe uma
versao recente em suporte padrao. Escolhe PostgreSQL 16 disponivel e guarda as
versoes fora do checkout, evitando mudar versoes em cada novo plan.

O tipo EC2 padrao e `c7i-flex.large` (x86), elegivel no novo Free Tier.
O script consulta essa elegibilidade antes do plano. Elegivel significa que
pode consumir os creditos do plano; nao significa uso ilimitado sem custo.

## Depois de revisar o plano

O script consulta a cota EC2 regional L-1216C47A. Tres c7i-flex.large precisam de
6 vCPUs; contas novas podem ter limite menor. plan exibe o aviso, e apply
interrompe antes de criar a infraestrutura se a cota for insuficiente ou
nao puder ser confirmada. Consulte Service Quotas > Amazon EC2 > Running
On-Demand Standard instances em us-east-2. Considere tambem outras EC2 ja
existentes na mesma cota. O script nao pede aumento de cota automaticamente.

```bash
bash scripts/personal.sh apply
```

Aplica somente o plano salvo e impede usar um plano de outro commit. Este e o
comando que cria a infraestrutura e inicia o consumo principal de recursos.
Se o apply falhar parcialmente, execute plan novamente usando o MESMO state;
nao apague state nem troque o bucket para tentar de novo.

Infraestrutura planejada:

- Uma VPC, duas subnets publicas e duas privadas; um NAT Gateway compartilhado.
- Um EKS toggle-cluster, com roles proprias para cluster e nodes.
- Tres nodes c7i-flex.large privados (6 vCPUs no total), com saida pelo NAT.
- Cinco repositorios ECR toggle-master/<servico>.
- Dois RDS db.t3.micro privados e criptografados: auth_db e target_db.
  O bootstrap GitOps cria flags_db no RDS de auth e inicializa os schemas.
- Redis dev-redis, privado; SGs dos bancos/cache aceitam somente o SG do EKS.
- SQS toggle-master-sqs e DynamoDB dev-dynamodb (HASH event_id).

O acesso Kubernetes inicial pertence a role criadora. Se trocar de identidade
AWS, pode ser necessario conceder acesso adicional ao cluster. As subnets ja
tem as tags para descoberta dos Load Balancers do Argo/Grafana.

## Instalar as aplicacoes

Depois do apply, consulte `bash scripts/personal.sh outputs`. Clone o GitOps:

```bash
git clone https://github.com/ramondata/toggle-master-gitops.git
cd toggle-master-gitops
export TARGET_REGION=us-east-2
bash academy/lab.sh publish
git pull --ff-only
bash academy/lab.sh up
```

O diretorio academy no GitOps tambem funciona nesta conta pessoal: o fluxo
atual utiliza as credenciais TEMPORARIAS da sessao CloudShell. Nao utiliza
LabRole nem exige criar uma role administrativa para o GitHub. OIDC para as
pipelines pode ser configurado separadamente; nao e criado por este modulo.

Quando `up` pedir a senha dos RDS, consulte o arquivo rds-password no seu
terminal, fora da gravacao, e informe-a na entrada oculta. Nao envie a senha
no chat. Na sessao seguinte, execute `export TARGET_REGION=us-east-2` e use `bash academy/lab.sh refresh` para renovar
as credenciais dos pods.

## Custos e encerramento

EKS, tres EC2, NAT, dois RDS, Redis e posteriormente Load Balancers sao recursos
cobrados. Nao e uma stack gratuita. Fechar o CloudShell nao desliga os recursos.
O modulo e um laboratorio: NAT unico, poucas replicas, Redis sem TLS de
transporte e dados descartaveis no encerramento, sem snapshot final RDS.

Para encerrar, primeiro remova os Services LoadBalancer pelo Kubernetes,
aguarde a exclusao dos LBs e depois, na raiz do Terraform:

```bash
bash scripts/personal.sh destroy
```

O Terraform solicita confirmacao. Esse destroy apaga os bancos e as imagens
ECR deste laboratorio. O bucket de state permanece para manter o historico.
Esta instrucao nao autoriza apagar recursos preexistentes ou de outros projetos.

## Retomar o node group que falhou no plano Free

Confirme conta 172346499417 e regiao Ohio. Pare uma execucao antiga de
academy/lab.sh up antes de aplicar o novo plano. Nao execute destroy.

Na raiz do Terraform, atualize o codigo e gere um plano:

```bash
git pull --ff-only
bash scripts/personal.sh plan
```

O plano deve substituir apenas o grupo toggle-cluster-nodes que falhou,
trocando t3.medium por c7i-flex.large. Confira que EKS, VPC, RDS e demais
recursos existentes nao serao substituidos e que as senhas nao serao alteradas.
Se aparecer recriacao de bancos/cluster ou colisao com um grupo nao gerenciado
no state, pare e revise o plano; nao apague state nem importe outro ambiente.

Depois dessa revisao:

```bash
bash scripts/personal.sh apply
kubectl get nodes -o wide
```

Com tres nos Ready, retome no GitOps (nao precisa republicar imagens que ja
terminaram com sucesso nesta conta/regiao):

```bash
cd ~/toggle-master-gitops
git pull --ff-only
export TARGET_REGION=us-east-2
bash academy/lab.sh up
```
