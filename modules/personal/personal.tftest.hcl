mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::172346499417:role/test-role" }
  }
}
override_resource {
  target = aws_subnet.private[0]
  values = { id = "subnet-0123456789abcdef0" }
}
override_resource {
  target = aws_subnet.private[1]
  values = { id = "subnet-0123456789abcdef1" }
}
override_resource {
  target          = aws_sqs_queue.events
  override_during = plan
  values = {
    arn = "arn:aws:sqs:us-east-2:172346499417:toggle-master-sqs"
  }
}
override_resource {
  target          = aws_dynamodb_table.events
  override_during = plan
  values = {
    arn = "arn:aws:dynamodb:us-east-2:172346499417:table/dev-dynamodb"
  }
}
variables {
  account_id         = "172346499417"
  eks_version        = "1.36"
  rds_engine_version = "16.10"
  db_password        = "test-only-not-a-real-password-123"
}
run "new_account_plan" {
  command = plan
  assert {
    condition     = var.region == "us-east-2" && aws_subnet.public[0].availability_zone == "us-east-2a" && aws_subnet.private[1].availability_zone == "us-east-2b"
    error_message = "O ambiente pessoal deve usar Ohio por padrao, incluindo as subnets."
  }
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].desired_size == 3
    error_message = "A stack exige tres nos por padrao."
  }
  assert {
    condition     = length(aws_eks_node_group.main.instance_types) == 1 && contains(aws_eks_node_group.main.instance_types, "c7i-flex.large")
    error_message = "Os nos devem usar o tipo x86 elegivel no novo Free Tier."
  }
  assert {
    condition     = aws_eks_addon.pod_identity.addon_name == "eks-pod-identity-agent" && length(aws_eks_pod_identity_association.workload) == 2
    error_message = "Evaluation e analytics precisam das duas associacoes Pod Identity."
  }
  assert {
    condition     = alltrue([for name, association in aws_eks_pod_identity_association.workload : association.namespace == "toggle-master" && association.service_account == name])
    error_message = "Associacoes devem usar contas de servico exclusivas no namespace da aplicacao."
  }
  assert {
    condition     = alltrue([for role in aws_iam_role.workload : jsondecode(role.assume_role_policy).Statement[0].Principal.Service == "pods.eks.amazonaws.com"])
    error_message = "As roles dos pods devem confiar no servico Pod Identity."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.evaluation.policy).Statement[0].Action == ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    error_message = "Evaluation deve apenas publicar na fila do projeto."
  }
  assert {
    condition     = aws_iam_role.ci_publisher.max_session_duration == 3600 && jsondecode(aws_iam_role.ci_publisher.assume_role_policy).Statement[0].Condition.ArnLike["aws:PrincipalArn"] == ["arn:aws:iam::172346499417:role/AccountFullAccessRole", "arn:aws:iam::172346499417:role/*/AccountFullAccessRole"]
    error_message = "Somente a role administrativa desta conta pode assumir o publicador, por uma hora."
  }
  assert {
    condition     = length(jsondecode(aws_iam_role_policy.ci_publisher.policy).Statement[1].Resource) == 5 && alltrue([for arn in jsondecode(aws_iam_role_policy.ci_publisher.policy).Statement[1].Resource : startswith(arn, "arn:aws:ecr:us-east-2:172346499417:repository/toggle-master/")])
    error_message = "O publicador deve acessar somente os cinco repositorios ECR deste projeto."
  }
  assert {
    condition     = length(aws_ecr_repository.service) == 5
    error_message = "Precisamos dos cinco repositorios ECR."
  }
  assert {
    condition     = length(aws_db_instance.postgres) == 2 && alltrue([for db in aws_db_instance.postgres : !db.publicly_accessible && db.storage_encrypted])
    error_message = "RDS deve ser privado e criptografado; flags_db compartilha o RDS auth."
  }
  assert {
    condition     = jsondecode(aws_iam_role.cluster.assume_role_policy).Statement[0].Principal.Service == "eks.amazonaws.com" && jsondecode(aws_iam_role.nodes.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Roles proprias e separadas para EKS e EC2, sem LabRole."
  }
  assert {
    condition     = aws_subnet.public[0].tags["kubernetes.io/role/elb"] == "1" && aws_subnet.private[0].tags["kubernetes.io/role/internal-elb"] == "1"
    error_message = "Load Balancers precisam descobrir as subnets corretas."
  }
}
run "reject_undersized_cluster" {
  command = plan
  variables { node_count = 1 }
  expect_failures = [var.node_count]
}
run "reject_short_password" {
  command = plan
  variables { db_password = "short" }
  expect_failures = [var.db_password]
}
