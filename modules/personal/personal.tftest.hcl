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
