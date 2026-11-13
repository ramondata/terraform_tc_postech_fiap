#!/usr/bin/env bash
# Usa um backend isolado, sem depender do cache Terragrunt de outra sessao.
set -euo pipefail
set +x
umask 077
export PATH="$HOME/.local/bin:$PATH"
export AWS_PAGER=""
lock_id="${1:-}"
[[ "$lock_id" =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] || {
  echo 'Uso: bash scripts/unlock-personal.sh ID_DA_TRAVA' >&2; exit 2;
}
for tool in aws terraform; do
  command -v "$tool" >/dev/null || { echo "Comando ausente: $tool. Execute bash scripts/install-tools.sh." >&2; exit 2; }
done
region="${PERSONAL_REGION:-us-east-2}"
[[ "$region" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]$ ]] || { echo 'Regiao invalida.' >&2; exit 2; }
account="$(aws sts get-caller-identity --region "$region" --query Account --output text)"
[[ "$account" == 172346499417 ]] || { echo "Conta incorreta: $account. Esperada 172346499417." >&2; exit 2; }
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cat > "$work/main.tf" <<'HCL'
terraform {
  backend "s3" {}
}
HCL
terraform -chdir="$work" init -input=false \
  -backend-config="bucket=toggle-tfstate-$account-$region" \
  -backend-config="key=personal/toggle-master/terraform.tfstate" \
  -backend-config="region=$region" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
echo "Conta $account | regiao $region | trava $lock_id"
echo 'Confirme somente se nenhum outro Terraform apply/plan/destroy estiver em execucao neste state.'
# Mantem a confirmacao interativa do Terraform; nao usa -force nem -lock=false.
terraform -chdir="$work" force-unlock "$lock_id"
