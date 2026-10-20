resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.lab_role
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-nodes"

  node_role_arn = var.lab_role

  subnet_ids = var.subnet_ids

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

}