variable "aws_oidc_provider_arn" {
  type = string
}

variable "repositories" {
  description = "Lista de repositórios ECR"
  type        = set(string)
}