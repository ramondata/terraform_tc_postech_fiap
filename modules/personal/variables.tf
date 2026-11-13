variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id deve ter 12 digitos."
  }
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "env" {
  type    = string
  default = "dev"
}
variable "cluster_name" {
  type    = string
  default = "toggle-cluster"
}
variable "eks_version" {
  type = string
}
variable "rds_engine_version" {
  type = string
}
variable "db_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "A senha RDS precisa ter pelo menos 16 caracteres."
  }
}
variable "node_count" {
  type    = number
  default = 3
  validation {
    condition     = var.node_count >= 3 && var.node_count <= 5 && floor(var.node_count) == var.node_count
    error_message = "Use entre 3 e 5 nos para esta stack de laboratorio."
  }
}
