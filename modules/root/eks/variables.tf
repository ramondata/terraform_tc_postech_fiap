variable "env" {
  description = "Ambiente de implantação (ex: dev, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets onde o EKS será criado"
  type        = list(string)
}

#variable "node_group_name" {
#  description = "Nome do managed node group"
#  type        = string
#}

variable "node_instance_types" {
  description = "Tipos de instância dos nodes"
  type        = list(string)
}

variable "desired_size" {
  description = "Quantidade desejada de nodes"
  type        = number
}

variable "min_size" {
  description = "Quantidade mínima de nodes"
  type        = number
}

variable "max_size" {
  description = "Quantidade máxima de nodes"
  type        = number
}