resource "aws_iam_role" "github_actions_ecr" {
  name = "github-actions-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = var.aws_oidc_provider_arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:*"
          }
        }
      }
    ]
  })
}



resource "aws_iam_policy" "github_actions_ecr_push" {
  name = "github-actions-ecr-push"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRPushImage"
        Effect = "Allow"

        Action = [
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ]

        Resource = "*"
      },

      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    team = "fiap"
  }
}