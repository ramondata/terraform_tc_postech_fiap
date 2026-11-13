#!/usr/bin/env bash
# Versoes usadas pelo CI; instalacao local sem sudo no AWS CloudShell.
set -euo pipefail
umask 077
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
  echo 'Este instalador requer Linux x86_64 (AWS CloudShell).' >&2
  exit 2
}
for tool in curl sha256sum unzip install; do
  command -v "$tool" >/dev/null || { echo "Comando ausente: $tool" >&2; exit 2; }
done
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$HOME/.local/bin"
cd "$work"
tf_version=1.17.2
tg_version=1.2.2
archive="terraform_${tf_version}_linux_amd64.zip"
base="https://releases.hashicorp.com/terraform/$tf_version"
curl -fsSL --connect-timeout 10 --max-time 180 "$base/$archive" -o "$archive"
curl -fsSL --connect-timeout 10 --max-time 60 "$base/terraform_${tf_version}_SHA256SUMS" -o terraform_SHA256SUMS
awk -v file="$archive" '$2 == file {print}' terraform_SHA256SUMS > selected_SHA256SUMS
[[ -s selected_SHA256SUMS ]] || { echo 'Checksum do Terraform nao encontrado.' >&2; exit 2; }
sha256sum --check --status selected_SHA256SUMS
unzip -q "$archive" terraform
install -m 755 terraform "$HOME/.local/bin/terraform"
curl -fsSL --connect-timeout 10 --max-time 180 \
  "https://github.com/gruntwork-io/terragrunt/releases/download/v$tg_version/terragrunt_linux_amd64" -o terragrunt
printf '%s  %s\n' 1ba4ad11cf6ac277e8ba59a3fdceb8576778e22f6a24bedd542e91bad9f36491 terragrunt | sha256sum --check --status
install -m 755 terragrunt "$HOME/.local/bin/terragrunt"
"$HOME/.local/bin/terraform" version
"$HOME/.local/bin/terragrunt" --version
echo 'Ferramentas instaladas em ~/.local/bin. O personal.sh configura o PATH automaticamente.'
