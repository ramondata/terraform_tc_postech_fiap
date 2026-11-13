resource "aws_security_group" "rds" {
  name   = "${var.env}-rds-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description     = "PostgreSQL somente dos nos EKS"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}
resource "aws_db_instance" "postgres" {
  for_each                = toset(["auth", "target"])
  identifier              = "${var.env}-${each.value}-service-database"
  engine                  = "postgres"
  engine_version          = var.rds_engine_version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = true
  db_name                 = "${each.value}_db"
  username                = "toggleadmin"
  password                = var.db_password
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
}
resource "aws_security_group" "redis" {
  name   = "${var.env}-redis-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description     = "Redis somente dos nos EKS"
    protocol        = "tcp"
    from_port       = 6379
    to_port         = 6379
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.env}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.env}-redis"
  description                = "Redis ToggleMaster laboratorio"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
}
resource "aws_sqs_queue" "events" {
  name                       = "toggle-master-sqs"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
}
resource "aws_dynamodb_table" "events" {
  name         = "${var.env}-dynamodb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  attribute {
    name = "event_id"
    type = "S"
  }
}
resource "aws_ecr_repository" "service" {
  for_each             = local.services
  name                 = "toggle-master/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}
