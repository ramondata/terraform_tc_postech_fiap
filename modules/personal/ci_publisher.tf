# Sessao de publicacao de uma hora, sem chaves permanentes nem acesso administrativo.
resource "aws_iam_role" "ci_publisher" {
  name                 = "${var.cluster_name}-ci-publisher"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = [
            "arn:aws:iam::${var.account_id}:role/AccountFullAccessRole",
            "arn:aws:iam::${var.account_id}:role/*/AccountFullAccessRole"
          ]
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "ci_publisher" {
  name = "publish-project-images"
  role = aws_iam_role.ci_publisher.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
          "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories", "ecr:DescribeImages"
        ]
        Resource = [for service in sort(tolist(local.services)) : "arn:aws:ecr:${var.region}:${var.account_id}:repository/toggle-master/${service}"]
      }
    ]
  })
}
