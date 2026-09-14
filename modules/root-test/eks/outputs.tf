output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint do Kubernetes"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_arn" {
  description = "ARN do cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "cluster_security_group_id" {
  description = "Security Group criado pelo EKS"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}