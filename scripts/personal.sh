#!/usr/bin/env bash
# CloudShell: prepara state proprio e plano; apply e uma acao separada.
set -euo pipefail
set +x
umask 077
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-plan}"
case "$mode" in plan|apply|outputs|destroy) ;; *) echo 'Uso: bash scripts/personal.sh plan|apply|outputs|destroy'; exit 2 ;; esac
for tool in aws terraform terragrunt python3; do command -v "$tool" >/dev/null || { echo "Comando ausente: $tool" >&2; exit 2; }; done
export PERSONAL_REGION="${PERSONAL_REGION:-us-east-2}"
export AWS_REGION="$PERSONAL_REGION" AWS_DEFAULT_REGION="$PERSONAL_REGION" AWS_PAGER=""
export TG_TF_PATH
TG_TF_PATH="$(command -v terraform)"
expected=172346499417
account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$account" == "$expected" ]] || { echo "Conta incorreta: esperado $expected, recebido $account. Nada foi criado." >&2; exit 2; }
if [[ "$mode" == plan || "$mode" == apply ]]; then
  quota="$(aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --query Quota.Value --output text 2>/dev/null || true)"
  if [[ "$quota" =~ ^[0-9]+([.][0-9]+)?$ ]] && (( ${quota%%.*} >= 6 )); then
    printf 'Cota EC2 Standard regional: %s vCPUs; este cluster usa 6.\n' "$quota"
  else
    printf 'ATENCAO: cota EC2 Standard informada=%s. Precisamos de pelo menos 6 vCPUs, alem de outras instancias existentes.\n' "${quota:-indisponivel}" >&2
    echo "Confira Service Quotas > Amazon EC2 > Running On-Demand Standard instances, em $PERSONAL_REGION." >&2
    [[ "$mode" != apply ]] || { echo 'Apply interrompido antes de criar a infraestrutura; confirme/aumente a cota primeiro.' >&2; exit 2; }
  fi
fi
STATE="$HOME/.toggle-personal/$account/$PERSONAL_REGION"
mkdir -p "$STATE"
chmod 700 "$STATE"
export PERSONAL_STATE_BUCKET="toggle-tfstate-$account-$PERSONAL_REGION"
export TF_PLUGIN_CACHE_DIR="/tmp/toggle-personal-$account-$PERSONAL_REGION/plugins"
export TG_DOWNLOAD_DIR="/tmp/toggle-personal-$account-$PERSONAL_REGION/terragrunt"
mkdir -p "$TF_PLUGIN_CACHE_DIR" "$TG_DOWNLOAD_DIR"
chmod 700 "/tmp/toggle-personal-$account-$PERSONAL_REGION"

if [[ "$mode" == plan ]]; then
  eligible="$(aws ec2 describe-instance-types --instance-types c7i-flex.large --query 'InstanceTypes[0].FreeTierEligible' --output text)"
  [[ "$eligible" == True || "$eligible" == true ]] || { echo 'c7i-flex.large nao consta como elegivel no Free Tier desta regiao. Plano interrompido.' >&2; exit 2; }
  # Apenas o bucket de state e preparado antes do plano da infraestrutura.
  if ! aws s3api head-bucket --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" >/dev/null 2>&1; then
    bucket_args=(--bucket "$PERSONAL_STATE_BUCKET" --region "$PERSONAL_REGION")
    if [[ "$PERSONAL_REGION" != us-east-1 ]]; then
      bucket_args+=(--create-bucket-configuration "LocationConstraint=$PERSONAL_REGION")
    fi
    aws s3api create-bucket "${bucket_args[@]}" >/dev/null
  fi
  aws s3api head-bucket --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account"
  aws s3api put-public-access-block --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-versioning --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  # Recupera o segredo e as versoes se a sessao CloudShell perdeu arquivos locais.
  remote_key="personal/toggle-master/terraform.tfstate"
  aws s3api list-objects-v2 --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" \
    --prefix "$remote_key" --output json > "$STATE/state-index.json"
  if python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if any(o["Key"]==sys.argv[2] for o in d.get("Contents",[])) else 1)' "$STATE/state-index.json" "$remote_key"; then
    aws s3api get-object --bucket "$PERSONAL_STATE_BUCKET" --expected-bucket-owner "$account" \
      --key "$remote_key" "$STATE/recovery.tfstate" >/dev/null
    python3 "$ROOT/scripts/recover-personal-state.py" "$STATE/recovery.tfstate" "$STATE" "$account" "$PERSONAL_REGION"
    rm -f -- "$STATE/recovery.tfstate"
  fi
  if [[ ! -s "$STATE/rds-password" ]]; then
    python3 - "$STATE/rds-password" <<'PY'
from pathlib import Path
import secrets, sys
Path(sys.argv[1]).write_text(secrets.token_hex(24) + 'Aa1!')
PY
  fi
  if [[ ! -s "$STATE/versions.json" ]]; then
    aws eks describe-cluster-versions --output json > "$STATE/eks-available.json"
    aws rds describe-db-engine-versions --engine postgres --output json > "$STATE/rds-available.json"
    python3 - "$STATE" <<'PY'
import json, os, sys
from pathlib import Path
root=Path(sys.argv[1])
versions=json.loads((root/'eks-available.json').read_text())['clusterVersions']
supported=[v['clusterVersion'] for v in versions if v.get('versionStatus',v.get('status','')).replace('-','_').upper() == 'STANDARD_SUPPORT']
supported=[v for v in supported if tuple(map(int,v.split('.'))) >= (1,33)]
rds=[v['EngineVersion'] for v in json.loads((root/'rds-available.json').read_text())['DBEngineVersions'] if v['EngineVersion'].startswith('16.')]
if not supported or not rds:
    raise SystemExit('Nao foram encontradas versoes compativeis em suporte padrao. Nenhuma infraestrutura foi aplicada.')
# Prefere a versao ja usada no projeto se ainda estiver em suporte padrao.
eks='1.36' if '1.36' in supported else max(supported,key=lambda v:tuple(map(int,v.split('.'))))
pg=max(rds,key=lambda v:tuple(map(int,v.split('.'))))
(root/'versions.json').write_text(json.dumps({'eks':eks,'postgres':pg}))
PY
  fi
fi
[[ -s "$STATE/versions.json" && -s "$STATE/rds-password" ]] || { echo 'Execute primeiro: bash scripts/personal.sh plan' >&2; exit 2; }
export PERSONAL_EKS_VERSION PERSONAL_RDS_VERSION TF_VAR_db_password
PERSONAL_EKS_VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["eks"])' "$STATE/versions.json")"
PERSONAL_RDS_VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["postgres"])' "$STATE/versions.json")"
TF_VAR_db_password="$(cat "$STATE/rds-password")"
printf 'Conta %s | %s | EKS %s | PostgreSQL %s\n' "$account" "$PERSONAL_REGION" "$PERSONAL_EKS_VERSION" "$PERSONAL_RDS_VERSION"
cd "$ROOT/env/personal"
terragrunt run -- init -input=false
case "$mode" in
  plan)
    terragrunt run -- validate
    # Remove um plano antigo para impedir apply acidental depois de um novo plan falhar.
    rm -f -- "$STATE/infra.tfplan" "$STATE/plan-revision"
    terragrunt run -- plan -input=false -out="$STATE/infra.tfplan"
    git -C "$ROOT" rev-parse HEAD > "$STATE/plan-revision"
    echo 'Plano salvo. Nenhuma alteracao da infraestrutura foi aplicada nesta etapa.'
    echo 'Revise o plano antes de executar: bash scripts/personal.sh apply'
    ;;
  apply)
    [[ -s "$STATE/infra.tfplan" && -s "$STATE/plan-revision" ]] || { echo 'Plano salvo ausente; execute plan.' >&2; exit 2; }
    [[ "$(cat "$STATE/plan-revision")" == "$(git -C "$ROOT" rev-parse HEAD)" ]] || { echo 'O codigo mudou desde o plano. Execute plan novamente.' >&2; exit 2; }
    terragrunt run -- apply -input=false "$STATE/infra.tfplan"
    rm -f -- "$STATE/infra.tfplan" "$STATE/plan-revision"
    aws eks update-kubeconfig --name toggle-cluster --region "$PERSONAL_REGION"
    echo 'Infraestrutura criada. Agora use o repositorio toggle-master-gitops para publicar e instalar as aplicacoes.'
    ;;
  outputs) terragrunt run -- output ;;
  destroy)
    echo 'ATENCAO: destroy apaga os bancos e as imagens deste laboratorio. Nao ha snapshot final RDS.'
    terragrunt run -- destroy
    ;;
esac
