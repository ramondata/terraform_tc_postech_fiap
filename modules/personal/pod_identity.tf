# Credenciais dos pods renovadas pelo EKS, independentes da sessao CloudShell.
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_node_group.main]
}
resource "aws_iam_role" "workload" {
  for_each = toset(["evaluation-service", "analytics-service"])
  name     = "${var.cluster_name}-${each.key}-aws"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:RequestTag/kubernetes-namespace"       = "toggle-master"
          "aws:RequestTag/kubernetes-service-account" = each.key
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "evaluation" {
  name = "send-project-events"
  role = aws_iam_role.workload["evaluation-service"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.events.arn
    }]
  })
}
resource "aws_iam_role_policy" "analytics" {
  name = "consume-project-events"
  role = aws_iam_role.workload["analytics-service"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.events.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:Scan", "dynamodb:DescribeTable"]
        Resource = aws_dynamodb_table.events.arn
      }
    ]
  })
}
resource "aws_eks_pod_identity_association" "workload" {
  for_each        = aws_iam_role.workload
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "toggle-master"
  service_account = each.key
  role_arn        = each.value.arn
  depends_on      = [aws_eks_addon.pod_identity, aws_iam_role_policy.evaluation, aws_iam_role_policy.analytics]
}
