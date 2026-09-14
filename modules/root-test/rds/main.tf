# Subnet group para o RDS nas sub-redes privadas
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.env}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.env}-db-subnets" }
}

# SG restrito para o RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.env}-rds-sg"
  description = "Acesso controlado ao RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres interno"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # ajuste conforme sua VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.env}-rds-sg" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.env}-rds"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags                   = { Name = "${var.env}-rds" }
}
