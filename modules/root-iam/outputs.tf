output "aws_role_arn" {
  description = "ARN da IAM Role utilizada pelo GitHub Actions para executar o Terraform"
  value       = aws_iam_role.github_actions_terraform.arn
}


output "github_oidc_provider_arn" {
  value = local.github_oidc_provider_arn
}